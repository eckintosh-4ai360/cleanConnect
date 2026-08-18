-- updateRiderLocation mirrors GPS coordinates onto both the rider's own row
-- and (if they're mid-job) the assigned pickup_requests row. The second part
-- is the same cross-actor problem as accept_pickup/complete_pickup: riders
-- have no direct UPDATE policy on pickup_requests by design. security
-- definer with an explicit assigned_rider_id guard, same pattern as those.

create or replace function public.update_rider_location(
  p_lat double precision,
  p_lng double precision,
  p_heading double precision default null,
  p_speed double precision default null,
  p_current_job_id uuid default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_rider_id uuid := auth.uid();
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to update location.';
  end if;

  update public.riders
     set current_lat = p_lat,
         current_lng = p_lng,
         heading = coalesce(p_heading, 0),
         speed = coalesce(p_speed, 0),
         last_location_update = now()
   where id = v_rider_id;

  if p_current_job_id is not null then
    update public.pickup_requests
       set rider_lat = p_lat,
           rider_lng = p_lng,
           rider_heading = coalesce(p_heading, 0),
           rider_speed = coalesce(p_speed, 0),
           rider_location_updated_at = now()
     where id = p_current_job_id
       and assigned_rider_id = v_rider_id;
  end if;
end;
$$;
