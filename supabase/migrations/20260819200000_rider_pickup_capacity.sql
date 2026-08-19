-- Admin-configurable cap on how many pickups a rider can hold at once.
-- accept_pickup previously only checked the *request's* own status
-- ('pending'), so a single rider could accept an unlimited number of
-- requests. Adds a singleton app_settings knob (edited from Settings.jsx,
-- same pattern as the mNotify columns in
-- 20260819190000_sms_provider_settings.sql) and enforces it inside
-- accept_pickup itself, since that's the one place every accept path goes
-- through regardless of client.

alter table public.app_settings
  add column if not exists max_concurrent_pickups integer not null default 3;

create or replace function public.accept_pickup(p_request_id uuid)
returns public.pickup_requests
language plpgsql security definer set search_path = public as $$
declare
  v_rider_id uuid := auth.uid();
  v_rider_name text;
  v_row public.pickup_requests;
  v_limit integer;
  v_active_count integer;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to accept a pickup.';
  end if;

  select max_concurrent_pickups into v_limit from app_settings where id = true;
  v_limit := coalesce(v_limit, 3);

  select count(*) into v_active_count
    from pickup_requests
   where assigned_rider_id = v_rider_id and status = 'accepted';

  if v_active_count >= v_limit then
    raise exception 'You already have % active pickup(s) — the maximum allowed at once. Complete one before accepting another.', v_limit;
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
