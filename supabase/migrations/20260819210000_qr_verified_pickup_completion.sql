-- Real QR-code verification for pickup completion.
--
-- Previously the rider app's "scan" screen was entirely fake (a button that
-- set a hardcoded string, no camera, no lookup) and complete_pickup happily
-- marked any accepted request 'completed' with zero proof the rider was
-- actually at the right bin. This wires the already-provisioned
-- mobile_scanner dependency and the bins.serial_number/qr_code_data that
-- customers already have printed on their bin (see bin_management_screen.dart
-- and admin_create_bin_rpc.sql) into an actual verification step:
--
--   1. Rider scans a bin's QR (which encodes bins.serial_number).
--   2. verify_pickup_bin looks up that serial number and confirms the bin
--      belongs to *this* pickup's customer -- fast feedback before the rider
--      bothers entering a weight.
--   3. complete_pickup re-validates the same thing server-side (the actual
--      security boundary -- a modified client can't skip step 2 and still
--      get a bypass) and now requires a matching QR code to complete at all.
--
-- pickup_requests has no single bin_id (a request can cover multiple
-- bin_types), so the match is "this bin belongs to this pickup's customer",
-- not a stricter per-request bin id -- see collection_events.bin_id below
-- for where the specific scanned bin does get recorded.

alter table public.collection_events
  add column if not exists bin_id uuid references public.bins(id);

-- ── verify_pickup_bin: read-only pre-check, used right after a scan ────────
create or replace function public.verify_pickup_bin(
  p_request_id uuid,
  p_serial_number text
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_rider_id uuid := auth.uid();
  v_pickup public.pickup_requests;
  v_bin public.bins;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to verify a bin.';
  end if;

  select * into v_pickup from pickup_requests
   where id = p_request_id and assigned_rider_id = v_rider_id;

  if not found then
    return jsonb_build_object('verified', false, 'reason', 'not_your_pickup');
  end if;

  select * into v_bin from bins where serial_number = btrim(coalesce(p_serial_number, ''));

  if not found then
    return jsonb_build_object('verified', false, 'reason', 'bin_not_found');
  end if;

  if v_bin.customer_id <> v_pickup.customer_id then
    return jsonb_build_object('verified', false, 'reason', 'wrong_customer');
  end if;

  return jsonb_build_object(
    'verified', true,
    'bin_id', v_bin.id,
    'bin_type', v_bin.type,
    'bin_size', v_bin.size
  );
end;
$$;

-- ── complete_pickup: now requires the same match to actually persist ───────
-- Drop the old 3-required-arg signature explicitly -- `create or replace`
-- with an extra required parameter creates a second overload rather than
-- replacing it, which would leave the unverified old signature callable.
drop function if exists public.complete_pickup(uuid, numeric, text);

create or replace function public.complete_pickup(
  p_request_id uuid,
  p_weight_kg numeric,
  p_qr_code_data text,
  p_notes text default null
)
returns public.pickup_requests
language plpgsql security definer set search_path = public as $$
declare
  v_rider_id uuid := auth.uid();
  v_rider_name text;
  v_row public.pickup_requests;
  v_bin public.bins;
  v_carbon_offset numeric;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to complete a pickup.';
  end if;

  if p_qr_code_data is null or btrim(p_qr_code_data) = '' then
    raise exception 'Scan the customer''s bin QR code before completing this pickup.';
  end if;

  select * into v_row from public.pickup_requests
   where id = p_request_id and assigned_rider_id = v_rider_id and status = 'accepted';

  if not found then
    raise exception 'Pickup is not in an accepted state assigned to you.';
  end if;

  select * into v_bin from public.bins where serial_number = btrim(p_qr_code_data);

  if not found then
    raise exception 'This QR code does not match any registered bin.';
  end if;

  if v_bin.customer_id <> v_row.customer_id then
    raise exception 'This bin belongs to a different customer -- scan %''s bin instead.', coalesce(v_row.customer_name, 'the right customer');
  end if;

  -- Re-guard on assigned_rider_id/status here too (not just the read above):
  -- this is the actual atomic state-transition, so it's what stops two
  -- concurrent completions of the same pickup from both succeeding.
  update public.pickup_requests
     set status = 'completed',
         completed_at = now(),
         actual_weight_kg = p_weight_kg,
         completion_notes = p_notes
   where id = p_request_id and assigned_rider_id = v_rider_id and status = 'accepted'
  returning * into v_row;

  if not found then
    raise exception 'Pickup is not in an accepted state assigned to you.';
  end if;

  select full_name into v_rider_name from public.profiles where id = v_rider_id;
  v_carbon_offset := round((p_weight_kg * 0.52)::numeric, 1);

  insert into public.collection_events
    (rider_id, rider_name, customer_id, customer_name, address, bin_type, bin_id,
     weight_kg, carbon_offset, qr_verified, qr_code_data, status, notes, request_id)
  values
    (v_rider_id, v_rider_name, v_row.customer_id, v_row.customer_name, v_row.location,
     array_to_string(v_row.bin_types, ', '), v_bin.id, p_weight_kg, v_carbon_offset,
     true, p_qr_code_data, 'completed', p_notes, p_request_id);

  update public.riders
     set total_collections = total_collections + 1,
         total_weight_kg = total_weight_kg + p_weight_kg,
         earnings_this_month = earnings_this_month + (p_weight_kg * 0.15)
   where id = v_rider_id;

  update public.customers
     set last_pickup_completed_at = now(),
         next_pickup_date = null,
         next_pickup_time_slot = null,
         next_pickup_bin_types = null
   where id = v_row.customer_id
     and next_pickup_date = v_row.date;

  insert into public.admin_notifications (title, message, type, rider_id, rider_name, request_id, customer_id)
  values ('Pickup Completed', v_rider_name || ' completed the pickup for ' || coalesce(v_row.customer_name, 'a customer') || '.',
          'pickup_completed', v_rider_id, v_rider_name, p_request_id, v_row.customer_id);

  return v_row;
end;
$$;
