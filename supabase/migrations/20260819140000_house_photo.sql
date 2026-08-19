-- Riders navigating to a pickup often can't tell which building is the right
-- one -- GPS pins in dense areas can be off by tens of metres, and street
-- numbering is inconsistent in a lot of the areas this app operates in. The
-- registration screen already has an "Upload House Picture" step, but it was
-- writing the device's local file path into profiles.profile_picture_url
-- (already the account avatar column, shared with riders/admins) instead of
-- actually uploading anything -- so no photo ever survived past the
-- customer's own device. This gives the photo its own column and its own
-- Storage bucket, and snapshots the URL onto each pickup_requests row the
-- same way customer_name/customer_email/customer_phone already are, since
-- riders have no standing SELECT access to a still-pending request's
-- customer row (pickup_requests_select_rider only grants that once the
-- request is 'pending' or assigned to them -- the customers table's own
-- assigned-rider policy is narrower still).

alter table public.customers
  add column if not exists house_photo_url text;

comment on column public.customers.house_photo_url is
  'Photo of the customer''s house/building captured at registration, so a rider can visually confirm the address. Null if the customer skipped the upload.';

alter table public.pickup_requests
  add column if not exists house_photo_url text;

comment on column public.pickup_requests.house_photo_url is
  'Snapshot of customers.house_photo_url at schedule_pickup time -- see customer_name for why this is copied rather than joined.';

-- schedule_pickup now also snapshots the customer's house photo.
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
  p_receipt_number text default null,
  p_location_lat double precision default null,
  p_location_lng double precision default null
)
returns public.pickup_requests
language plpgsql security invoker as $$
declare
  v_customer_id uuid := auth.uid();
  v_customer_name text;
  v_customer_email text;
  v_house_photo_url text;
  v_request public.pickup_requests;
  v_lat double precision := p_location_lat;
  v_lng double precision := p_location_lng;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to schedule a pickup.';
  end if;

  select full_name, email into v_customer_name, v_customer_email
    from public.profiles where id = v_customer_id;

  select house_photo_url into v_house_photo_url
    from public.customers where id = v_customer_id;

  if v_lat is null and p_location ~ '-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+' then
    v_lat := (substring(p_location from '(-?\d{1,3}\.\d+)\s*,\s*-?\d{1,3}\.\d+'))::double precision;
    v_lng := (substring(p_location from '-?\d{1,3}\.\d+\s*,\s*(-?\d{1,3}\.\d+)'))::double precision;
  end if;

  if v_lat is not null and (abs(v_lat) > 90 or abs(v_lng) > 180) then
    v_lat := null;
    v_lng := null;
  end if;

  insert into public.pickup_requests (
    customer_id, customer_name, customer_email, bin_types, date, time_slot, location,
    location_lat, location_lng, house_photo_url,
    instructions, status, payment_status, amount_paid, original_amount,
    discount_applied_percentage, surcharge_applied_percentage, payment_method, paid_at
  )
  values (
    v_customer_id, v_customer_name, v_customer_email, p_bin_types, p_date, p_time_slot, p_location,
    v_lat, v_lng, v_house_photo_url,
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

-- ── Storage: house/building photos ──────────────────────────────────────────
-- Same shape as the incident-reports bucket: public read (the app has no
-- signed-URL refresh logic anywhere, so every stored media URL is permanent),
-- insert restricted to the customer's own uid-prefixed folder. One file per
-- customer at a fixed path so re-uploading (e.g. from profile settings later)
-- overwrites instead of accumulating.

insert into storage.buckets (id, name, public)
values ('house-photos', 'house-photos', true)
on conflict (id) do nothing;

create policy "house_photos_storage_insert_own"
  on storage.objects for insert
  with check (bucket_id = 'house-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "house_photos_storage_update_own"
  on storage.objects for update
  using (bucket_id = 'house-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "house_photos_storage_public_read"
  on storage.objects for select
  using (bucket_id = 'house-photos');
