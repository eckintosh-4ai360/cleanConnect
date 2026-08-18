-- Phase 4: customer-domain RPCs (bins, bin requests, pickups, balance,
-- incident reports) plus the Storage bucket for incident-report media.
--
-- These are RPCs rather than plain client-side updates for a real technical
-- reason, not just consistency with accept_pickup/complete_pickup: Postgrest
-- has no equivalent of Firestore's FieldValue.increment() — a client can only
-- set a column to a literal value, not "column = column + 1". Counter fields
-- (registered_bins_count, active_requests_count, pending_bin_requests_count)
-- need a server-side atomic UPDATE or they'd race under concurrent writes.
-- All security invoker (respect RLS) since every RPC only ever touches the
-- calling customer's own rows.

create or replace function public.register_bin(
  p_serial_number text,
  p_type text,
  p_size text,
  p_frequency text,
  p_pickup_days text[],
  p_gps_location text,
  p_photo_path text default null
)
returns public.bins
language plpgsql security invoker as $$
declare
  v_customer_id uuid := auth.uid();
  v_customer_name text;
  v_bin public.bins;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to register a bin.';
  end if;

  select full_name into v_customer_name from public.profiles where id = v_customer_id;

  insert into public.bins (
    customer_id, serial_number, type, size, ownership, status,
    fill_level_percentage, schedule_frequency, pickup_days, gps_location, verification_photo_url
  )
  values (
    v_customer_id, p_serial_number, p_type, p_size, 'personal', 'active',
    0, p_frequency, p_pickup_days, p_gps_location, p_photo_path
  )
  returning * into v_bin;

  update public.customers
     set registered_bins_count = registered_bins_count + 1,
         contract_type = 'Residential',
         subscription_plan_name = p_frequency || ' Plan',
         subscription_status = 'active'
   where id = v_customer_id;

  insert into public.admin_notifications (title, message, type, customer_id, customer_name)
  values ('New Bin Registered', v_customer_name || ' registered a ' || p_size || ' ' || p_type || ' bin.',
          'bin_registered', v_customer_id, v_customer_name);

  return v_bin;
end;
$$;

create or replace function public.request_company_bin(
  p_type text,
  p_size text,
  p_gps_location text
)
returns public.bin_requests
language plpgsql security invoker as $$
declare
  v_customer_id uuid := auth.uid();
  v_customer_name text;
  v_request public.bin_requests;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to request a bin.';
  end if;

  select full_name into v_customer_name from public.profiles where id = v_customer_id;

  insert into public.bin_requests (customer_id, type, size, gps_location, status)
  values (v_customer_id, p_type, p_size, p_gps_location, 'pending')
  returning * into v_request;

  update public.customers
     set pending_bin_requests_count = pending_bin_requests_count + 1
   where id = v_customer_id;

  insert into public.admin_notifications (title, message, type, customer_id, customer_name, request_id)
  values ('New Bin Requested',
          v_customer_name || ' requested a company-owned ' || p_size || ' ' || p_type ||
            ' bin. Admin should assign a bin with a serial number.',
          'bin_requested', v_customer_id, v_customer_name, v_request.id);

  return v_request;
end;
$$;

create or replace function public.schedule_pickup(
  p_bin_types text[],
  p_date timestamptz,
  p_time_slot text,
  p_location text,
  p_amount_paid numeric,
  p_payment_method text,
  p_instructions text default null,
  p_original_amount numeric default 0,
  p_discount_applied_percentage numeric default 0,
  p_surcharge_applied_percentage numeric default 0,
  p_receipt_number text default null
)
returns public.pickup_requests
language plpgsql security invoker as $$
declare
  v_customer_id uuid := auth.uid();
  v_customer_name text;
  v_customer_email text;
  v_request public.pickup_requests;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to schedule a pickup.';
  end if;

  select full_name, email into v_customer_name, v_customer_email
    from public.profiles where id = v_customer_id;

  insert into public.pickup_requests (
    customer_id, customer_name, customer_email, bin_types, date, time_slot, location,
    instructions, status, payment_status, amount_paid, original_amount,
    discount_applied_percentage, surcharge_applied_percentage, payment_method, paid_at
  )
  values (
    v_customer_id, v_customer_name, v_customer_email, p_bin_types, p_date, p_time_slot, p_location,
    p_instructions, 'pending', 'paid', p_amount_paid,
    case when p_original_amount > 0 then p_original_amount else p_amount_paid end,
    p_discount_applied_percentage, p_surcharge_applied_percentage, p_payment_method, now()
  )
  returning * into v_request;

  insert into public.service_history (customer_id, title, type, status, amount_paid, payment_method, receipt_number, pickup_request_id)
  values (
    v_customer_id,
    case when p_discount_applied_percentage > 0
      then 'Pickup Payment (' || p_discount_applied_percentage::int || '% Delay Bonus Applied)'
      else 'Pickup Request Payment' end,
    'payment', 'completed', p_amount_paid, p_payment_method, p_receipt_number, v_request.id
  );

  update public.customers
     set active_requests_count = active_requests_count + 1,
         last_pickup_request_date = now(),
         next_pickup_date = p_date,
         next_pickup_time_slot = p_time_slot,
         next_pickup_bin_types = p_bin_types,
         payment_method = p_payment_method,
         delay_bonus_redeemed_at = case when p_discount_applied_percentage > 0 then now() else delay_bonus_redeemed_at end
   where id = v_customer_id;

  insert into public.admin_notifications (title, message, type, customer_id, customer_name, request_id)
  values (
    'Pickup Requested',
    v_customer_name || ' paid GHS ' || to_char(p_amount_paid, 'FM999999990.00') ||
      case when p_discount_applied_percentage > 0
        then ' (with ' || p_discount_applied_percentage::int || '% Delay Bonus)' else '' end ||
      ' and requested pickup for ' || array_to_string(p_bin_types, ', ') || ' (' || p_time_slot || ' at ' || p_location || ').',
    'pickup_requested', v_customer_id, v_customer_name, v_request.id
  );

  return v_request;
end;
$$;

create or replace function public.pay_outstanding_balance(p_receipt_number text default null)
returns public.customers
language plpgsql security invoker as $$
declare
  v_customer_id uuid := auth.uid();
  v_amount numeric;
  v_customer public.customers;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to pay a balance.';
  end if;

  select outstanding_balance into v_amount from public.customers where id = v_customer_id;

  update public.customers
     set outstanding_balance = 0
   where id = v_customer_id
  returning * into v_customer;

  insert into public.service_history (customer_id, title, type, status, amount_paid, receipt_number)
  values (v_customer_id, 'Outstanding Balance Payment', 'payment', 'completed', v_amount, p_receipt_number);

  return v_customer;
end;
$$;

create or replace function public.submit_incident_report(
  p_description text,
  p_location text,
  p_media_url text default null,
  p_media_type text default null
)
returns public.incident_reports
language plpgsql security invoker as $$
declare
  v_customer_id uuid := auth.uid();
  v_customer_name text;
  v_report public.incident_reports;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to submit a report.';
  end if;

  select full_name into v_customer_name from public.profiles where id = v_customer_id;

  insert into public.incident_reports (reporter_id, reporter_name, reporter_phone, description, location, media_url, media_type, status)
  select v_customer_id, v_customer_name, phone_number, p_description, p_location, p_media_url, p_media_type, 'pending'
    from public.profiles where id = v_customer_id
  returning * into v_report;

  insert into public.admin_notifications (title, message, type, customer_id, customer_name, request_id)
  values ('New Incident Reported', v_customer_name || ' reported an issue: ' || p_description,
          'incident_reported', v_customer_id, v_customer_name, v_report.id);

  return v_report;
end;
$$;

-- ── Storage: incident report media ──────────────────────────────────────────
-- Public bucket (parity with the app's existing pattern of storing a
-- permanent mediaUrl directly on the record — no signed-URL refresh logic
-- exists anywhere in the codebase). Path convention: {customer_id}/{report_id}/{filename}.

insert into storage.buckets (id, name, public)
values ('incident-reports', 'incident-reports', true)
on conflict (id) do nothing;

create policy "incident_reports_storage_insert_own"
  on storage.objects for insert
  with check (bucket_id = 'incident-reports' and (storage.foldername(name))[1] = auth.uid()::text);

-- Bucket is public, so read access is open to anyone with the URL (matches
-- the app's existing pattern of storing a permanent mediaUrl on the record).
create policy "incident_reports_storage_public_read"
  on storage.objects for select
  using (bucket_id = 'incident-reports');
