-- Phase 5: rider-domain RPCs, plus two fixes to accept_pickup/complete_pickup
-- found while implementing the rider repository:
--
-- 1. Wrong carbon-offset/earnings multipliers. The Phase 1 version of
--    complete_pickup had them swapped/wrong. The real app uses:
--      carbonOffset = weightKg * 0.52  (rounded to 1 decimal)
--      earnings     = weightKg * 0.15
--    but the Phase 1 RPC used 0.15 for carbon offset and 0.5 for earnings.
--
-- 2. Both RPCs were `security invoker`, but they update pickup_requests and
--    customers rows that do NOT belong to the calling rider under RLS
--    (riders deliberately have no generic UPDATE policy on pickup_requests,
--    and customers_update_own only allows a customer to update their own
--    row) — meaning these updates would silently affect 0 rows for a real
--    rider. That went unnoticed in Phase 3 because the only live test used a
--    nonexistent request id, so "RLS blocked it" and "no such pending row"
--    looked identical. Fixed by making both `security definer`, matching the
--    pattern already used for assign_incident_to_rider — the function's own
--    WHERE-clause guards (status='pending'/'accepted', assigned_rider_id)
--    are the real authorization now, not RLS.

create or replace function public.accept_pickup(p_request_id uuid)
returns public.pickup_requests
language plpgsql security definer set search_path = public as $$
declare
  v_rider_id uuid := auth.uid();
  v_rider_name text;
  v_row public.pickup_requests;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to accept a pickup.';
  end if;

  select full_name into v_rider_name from profiles where id = v_rider_id;

  update pickup_requests
     set status = 'accepted', assigned_rider_id = v_rider_id,
         assigned_rider_name = v_rider_name, accepted_at = now()
   where id = p_request_id and status = 'pending'
  returning * into v_row;

  if not found then
    raise exception 'This pickup was already accepted by another rider.';
  end if;

  insert into admin_notifications (title, message, type, rider_id, rider_name, request_id, customer_id)
  values ('Pickup Accepted', v_rider_name || ' accepted a pickup request.',
          'pickup_accepted', v_rider_id, v_rider_name, p_request_id, v_row.customer_id);

  return v_row;
end;
$$;

create or replace function public.complete_pickup(
  p_request_id uuid,
  p_weight_kg numeric,
  p_notes text default null
)
returns public.pickup_requests
language plpgsql security definer set search_path = public as $$
declare
  v_rider_id uuid := auth.uid();
  v_rider_name text;
  v_row public.pickup_requests;
  v_carbon_offset numeric;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to complete a pickup.';
  end if;

  update public.pickup_requests
     set status = 'completed',
         completed_at = now(),
         actual_weight_kg = p_weight_kg,
         completion_notes = p_notes
   where id = p_request_id
     and assigned_rider_id = v_rider_id
     and status = 'accepted'
  returning * into v_row;

  if not found then
    raise exception 'Pickup is not in an accepted state assigned to you.';
  end if;

  select full_name into v_rider_name from public.profiles where id = v_rider_id;
  v_carbon_offset := round((p_weight_kg * 0.52)::numeric, 1);

  insert into public.collection_events
    (rider_id, rider_name, customer_id, customer_name, address, bin_type,
     weight_kg, carbon_offset, status, notes, request_id)
  values
    (v_rider_id, v_rider_name, v_row.customer_id, v_row.customer_name, v_row.location,
     array_to_string(v_row.bin_types, ', '), p_weight_kg, v_carbon_offset, 'completed', p_notes, p_request_id);

  update public.riders
     set total_collections = total_collections + 1,
         total_weight_kg = total_weight_kg + p_weight_kg,
         earnings_this_month = earnings_this_month + (p_weight_kg * 0.15)
   where id = v_rider_id;

  -- only clear the customer's "next pickup" pointer if it still refers to *this* request
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

-- ── mark_stop_collected: closes a route stop and logs a collection event ───
create or replace function public.mark_stop_collected(
  p_stop_id uuid,
  p_weight_kg numeric,
  p_notes text default null,
  p_qr_code_data text default null
)
returns public.route_stops
language plpgsql security invoker as $$
declare
  v_rider_id uuid := auth.uid();
  v_rider_name text;
  v_stop public.route_stops;
  v_carbon_offset numeric;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to mark a stop collected.';
  end if;

  update public.route_stops
     set status = 'collected',
         actual_weight_kg = p_weight_kg,
         notes = coalesce(p_notes, notes),
         collected_at = now()
   where id = p_stop_id
     and exists (
       select 1 from public.routes r
        where r.id = route_stops.route_id and r.assigned_rider_id = v_rider_id
     )
  returning * into v_stop;

  if not found then
    raise exception 'Stop not found or not assigned to you.';
  end if;

  select full_name into v_rider_name from public.profiles where id = v_rider_id;
  v_carbon_offset := round((p_weight_kg * 0.52)::numeric, 1);

  insert into public.collection_events
    (rider_id, rider_name, customer_name, address, bin_type, weight_kg,
     carbon_offset, qr_verified, qr_code_data, status, notes, route_id)
  values
    (v_rider_id, v_rider_name, v_stop.customer_name, v_stop.address, v_stop.bin_type, p_weight_kg,
     v_carbon_offset, p_qr_code_data is not null and p_qr_code_data <> '', p_qr_code_data,
     'completed', p_notes, v_stop.route_id);

  update public.riders
     set total_collections = total_collections + 1,
         total_weight_kg = total_weight_kg + p_weight_kg,
         earnings_this_month = earnings_this_month + (p_weight_kg * 0.15)
   where id = v_rider_id;

  return v_stop;
end;
$$;
