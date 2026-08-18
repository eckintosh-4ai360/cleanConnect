-- Real Google Maps navigation needs a destination the map can actually plot.
-- pickup_requests already carried rider_lat/rider_lng (where the rider IS) but
-- the customer's doorstep only ever existed as `location`, a free-text column
-- that is sometimes "5.603700, -0.187000" (copied off a bin's gps_location) and
-- sometimes "Home Address". Geocoding that string on every map open would be
-- both slow and billable, so the coordinates get their own columns, captured
-- once at request time from the device that already knows them.

alter table public.pickup_requests
  add column if not exists location_lat double precision,
  add column if not exists location_lng double precision;

comment on column public.pickup_requests.location_lat is
  'Destination latitude for map/routing. Null for legacy rows whose location was a plain address.';
comment on column public.pickup_requests.location_lng is
  'Destination longitude for map/routing. Null for legacy rows whose location was a plain address.';

-- Backfill every historical row whose `location` already held coordinates.
-- The regex mirrors GeoUtils.tryParseLatLng on the Dart side: two signed
-- decimals separated by a comma, anywhere in the string, so values with a
-- "(Fallback)" suffix still resolve. Range-checked rather than clamped -- an
-- out-of-range match means the digits were never coordinates.
update public.pickup_requests
   set location_lat = (substring(location from '(-?\d{1,3}\.\d+)\s*,\s*-?\d{1,3}\.\d+'))::double precision,
       location_lng = (substring(location from '-?\d{1,3}\.\d+\s*,\s*(-?\d{1,3}\.\d+)'))::double precision
 where location_lat is null
   and location ~ '-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+';

update public.pickup_requests
   set location_lat = null, location_lng = null
 where location_lat is not null
   and (abs(location_lat) > 90 or abs(location_lng) > 180);

-- Riders open the navigation screen straight from the pending-pickups list, so
-- the plotted destination has to come back on the same stream query. No new
-- policy is needed: these columns sit on a table riders can already select.

-- schedule_pickup gains the two coordinates as optional trailing params. They
-- are optional so the existing 11-arg call sites keep resolving during rollout;
-- PostgREST matches RPCs by the argument names supplied, so an older client
-- that omits them still hits this same function.
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
  v_request public.pickup_requests;
  v_lat double precision := p_location_lat;
  v_lng double precision := p_location_lng;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to schedule a pickup.';
  end if;

  select full_name, email into v_customer_name, v_customer_email
    from public.profiles where id = v_customer_id;

  -- Fall back to parsing the location text when the client sent no explicit
  -- fix -- e.g. the address came from a saved bin whose gps_location is already
  -- a coordinate pair, or the device denied location permission at request time.
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
    location_lat, location_lng,
    instructions, status, payment_status, amount_paid, original_amount,
    discount_applied_percentage, surcharge_applied_percentage, payment_method, paid_at
  )
  values (
    v_customer_id, v_customer_name, v_customer_email, p_bin_types, p_date, p_time_slot, p_location,
    v_lat, v_lng,
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

-- Lets a customer attach coordinates to a request they already created, which
-- is how the tracking screen repairs a legacy row after a one-off geocode.
--
-- security definer, not invoker: customers deliberately have no UPDATE policy
-- on pickup_requests (only select + insert), so an invoker function would
-- silently match zero rows. Same shape as update_rider_location -- definer plus
-- an explicit ownership guard in the WHERE clause, which keeps the write
-- narrower than a blanket UPDATE policy would.
create or replace function public.set_pickup_destination(
  p_request_id uuid,
  p_lat double precision,
  p_lng double precision
)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Must be signed in to set a pickup destination.';
  end if;

  if abs(p_lat) > 90 or abs(p_lng) > 180 then
    raise exception 'Coordinates out of range: %, %', p_lat, p_lng;
  end if;

  update public.pickup_requests
     set location_lat = p_lat,
         location_lng = p_lng,
         updated_at = now()
   where id = p_request_id
     and customer_id = auth.uid();
end;
$$;

-- The tracking screen needs to show who is coming: name, photo, vehicle and a
-- phone number to call if the rider cannot find the gate. Customers have no
-- select policy on profiles or riders (both are own-row-or-admin), and widening
-- those policies would expose the whole fleet's contact details to every
-- customer. This returns only the contact card fields, only for a rider
-- actually assigned to the caller's own request, and only while that request is
-- still live -- so the disclosure ends when the job does.
create or replace function public.get_pickup_rider_card(p_request_id uuid)
returns table (
  rider_id      uuid,
  full_name     text,
  phone_number  text,
  photo_url     text,
  vehicle_type  text,
  rating        numeric
)
language sql security definer set search_path = public stable as $$
  select r.id, p.full_name, p.phone_number, p.profile_picture_url,
         r.vehicle_type, r.rating
    from public.pickup_requests pr
    join public.riders r   on r.id = pr.assigned_rider_id
    join public.profiles p on p.id = r.id
   where pr.id = p_request_id
     and pr.customer_id = auth.uid()
     and pr.status in ('accepted','assigned','confirmed');
$$;

revoke all on function public.get_pickup_rider_card(uuid) from public;
grant execute on function public.get_pickup_rider_card(uuid) to authenticated;
