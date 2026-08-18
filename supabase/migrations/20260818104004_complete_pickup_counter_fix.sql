-- complete_pickup's customer update was entirely gated on
-- "next_pickup_date = v_row.date", so last_pickup_completed_at and
-- active_requests_count only updated when the completed job happened to be
-- the customer's currently-displayed "next pickup". The original Dart code
-- (rider_repository_impl.dart completePickup) only gated the next_pickup_*
-- clearing on that match — lastPickupCompletedAt and activeRequestsCount
-- decrement unconditionally on every completion. Found via live testing:
-- active_requests_count stayed at 1 after completing the customer's only
-- pickup instead of dropping to 0.

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

  -- lastPickupCompletedAt/activeRequestsCount update on every completion;
  -- next_pickup_* only clears if it still refers to *this* request.
  update public.customers
     set last_pickup_completed_at = now(),
         active_requests_count = greatest(active_requests_count - 1, 0),
         next_pickup_date = case when next_pickup_date = v_row.date then null else next_pickup_date end,
         next_pickup_time_slot = case when next_pickup_date = v_row.date then null else next_pickup_time_slot end,
         next_pickup_bin_types = case when next_pickup_date = v_row.date then null else next_pickup_bin_types end
   where id = v_row.customer_id;

  insert into public.admin_notifications (title, message, type, rider_id, rider_name, request_id, customer_id)
  values ('Pickup Completed', v_rider_name || ' completed the pickup for ' || coalesce(v_row.customer_name, 'a customer') || '.',
          'pickup_completed', v_rider_id, v_rider_name, p_request_id, v_row.customer_id);

  return v_row;
end;
$$;
