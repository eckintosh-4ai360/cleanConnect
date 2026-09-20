-- Pickup requests only reach riders close enough to actually serve them.
--
-- Every pending request used to be broadcast to the whole fleet, so a customer
-- in Tarkwa rang the phone of a rider in Accra 230 km away. Dispatch is now
-- scoped by distance: a new request is offered to riders within
-- app_settings.pickup_discovery_radius_km (default 4 km) of the pickup address.
--
-- Nothing may strand as a result. If no rider inside that circle has taken the
-- request after a few minutes, escalate_pickup_discovery widens the circle a
-- step at a time up to pickup_discovery_max_radius_km, notifying only the
-- riders in the new ring so nobody is rung twice for the same job. The final
-- step also reaches riders whose position is unknown or stale, which is the
-- only way a rider who has never shared a fix can still be dispatched.
--
-- Distance is straight-line (haversine) against the rider's last reported fix,
-- deliberately the same formula as GeoUtils.distanceMeters on the Dart side so
-- the rider's in-app list and the server's push agree on who counts as near.

-- ── Settings ───────────────────────────────────────────────────────────────
alter table public.app_settings
  add column if not exists pickup_discovery_radius_km          numeric(6,2) not null default 4,
  add column if not exists pickup_discovery_max_radius_km      numeric(6,2) not null default 12,
  add column if not exists pickup_discovery_escalation_minutes integer      not null default 3,
  add column if not exists rider_location_max_age_minutes      integer      not null default 720;

do $$
begin
  alter table public.app_settings
    add constraint app_settings_pickup_discovery_range
    check (pickup_discovery_radius_km > 0
           and pickup_discovery_max_radius_km >= pickup_discovery_radius_km
           and pickup_discovery_escalation_minutes >= 1
           and rider_location_max_age_minutes >= 1);
exception when duplicate_object then null;
end;
$$;

comment on column public.app_settings.pickup_discovery_radius_km is
  'How far from the pickup address a rider may be and still be offered a new request. The circle a request opens in.';
comment on column public.app_settings.pickup_discovery_max_radius_km is
  'Widest the circle may grow when nobody nearby takes a request. Set equal to pickup_discovery_radius_km to switch escalation off.';
comment on column public.app_settings.pickup_discovery_escalation_minutes is
  'Minutes an unclaimed request waits at its current radius before the circle widens.';
comment on column public.app_settings.rider_location_max_age_minutes is
  'How old a rider GPS fix may be and still be trusted to place them. Generous by default: a phone that backgrounded the app overnight should still get the next morning work.';

-- ── How far a request has been offered so far ──────────────────────────────
alter table public.pickup_requests
  add column if not exists discovery_radius_km   numeric(6,2),
  add column if not exists discovery_notified_at timestamptz;

comment on column public.pickup_requests.discovery_radius_km is
  'Radius (km) this request has been broadcast to so far. Null means it was never distance-scoped — a legacy row, or one with no coordinates.';
comment on column public.pickup_requests.discovery_notified_at is
  'When riders were last alerted about this request, at discovery_radius_km.';

-- ── Geometry ───────────────────────────────────────────────────────────────
-- Haversine, metres. Mirrors GeoUtils.distanceMeters (lib/core/utils/geo_utils.dart).
create or replace function public.distance_meters(
  p_lat1 double precision,
  p_lng1 double precision,
  p_lat2 double precision,
  p_lng2 double precision
)
returns double precision
language sql immutable parallel safe as $$
  select 2 * 6371000.0 * asin(least(1.0, sqrt(
    sin(radians(p_lat2 - p_lat1) / 2) ^ 2 +
    cos(radians(p_lat1)) * cos(radians(p_lat2)) * sin(radians(p_lng2 - p_lng1) / 2) ^ 2
  )));
$$;

comment on function public.distance_meters(double precision, double precision, double precision, double precision) is
  'Great-circle distance in metres. Straight-line, not road distance — dispatch only needs to know who is plausibly close.';

-- Riders reachable by push whose last known position falls in the ring
-- (p_min_radius_km, p_radius_km] around a point. The inner bound lets an
-- escalation alert only the newly covered riders instead of everyone again.
--
-- security definer: this reads the whole fleet's positions, which no rider or
-- customer may select directly. Every caller is a server-side dispatch
-- function, so execute stays revoked from the client roles.
create or replace function public.riders_near(
  p_lat double precision,
  p_lng double precision,
  p_radius_km numeric,
  p_include_unlocated boolean default false,
  p_min_radius_km numeric default 0
)
returns uuid[]
language plpgsql stable security definer set search_path = public as $$
declare
  v_max_age integer;
  v_cutoff  timestamptz;
  v_ids     uuid[];
begin
  select coalesce(rider_location_max_age_minutes, 720) into v_max_age
    from public.app_settings where id = true;
  v_cutoff := now() - make_interval(mins => coalesce(v_max_age, 720));

  select coalesce(array_agg(r.id), '{}'::uuid[]) into v_ids
    from public.riders r
   where r.fcm_token is not null
     and r.status <> 'disabled'
     and case
           when r.current_lat is null or r.current_lng is null
                or r.last_location_update is null or r.last_location_update <= v_cutoff
             -- Position unknown or too old to trust: only the last and widest
             -- step reaches these riders.
             then p_include_unlocated
           else public.distance_meters(p_lat, p_lng, r.current_lat, r.current_lng)
                  <= p_radius_km * 1000
                -- Strictly outside the inner bound, so an escalation skips the
                -- riders it already rang. A zero inner bound keeps everyone,
                -- including a rider standing on the doorstep.
                and (p_min_radius_km <= 0
                     or public.distance_meters(p_lat, p_lng, r.current_lat, r.current_lng)
                          > p_min_radius_km * 1000)
         end;

  return v_ids;
end;
$$;

revoke execute on function public.riders_near(double precision, double precision, numeric, boolean, numeric)
  from public, anon, authenticated;

-- The fleet is small, but every dispatch scans it. Keep the scan to the riders
-- who can actually be pushed to.
create index if not exists riders_dispatchable_idx
  on public.riders (last_location_update)
  where fcm_token is not null;

-- ── New request: offer it to the riders nearby ─────────────────────────────
-- Replaces the fleet-wide broadcast in 20260818113212_notify_riders_trigger.sql.
-- Still fire-and-forget and still wrapped, so a dispatch problem can never roll
-- back the customer's pickup request.
create or replace function public.notify_riders_on_new_pickup()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_radius    numeric;
  v_rider_ids uuid[];
begin
  if new.status <> 'pending' then
    return new;
  end if;

  begin
    select coalesce(pickup_discovery_radius_km, 4) into v_radius
      from public.app_settings where id = true;
    v_radius := coalesce(v_radius, 4);

    if new.location_lat is not null and new.location_lng is not null then
      v_rider_ids := public.riders_near(new.location_lat, new.location_lng, v_radius);

      update public.pickup_requests
         set discovery_radius_km = v_radius,
             discovery_notified_at = now()
       where id = new.id;

      -- Nobody close enough yet. escalate_pickup_discovery widens the circle on
      -- its next run rather than waking the whole fleet now.
      if array_length(v_rider_ids, 1) is null then
        return new;
      end if;
    end if;

    -- A request with no coordinates cannot be placed on the map, so it keeps
    -- the old fleet-wide behaviour: riderIds null means every rider.
    perform public.push_to_riders(jsonb_build_object(
      'type', 'new_pickup_request',
      'riderIds', case when v_rider_ids is null then null::jsonb else to_jsonb(v_rider_ids) end,
      'requestId', new.id,
      'customerId', new.customer_id,
      'customerName', new.customer_name,
      'location', new.location,
      'locationLat', new.location_lat,
      'locationLng', new.location_lng,
      'radiusKm', v_radius,
      'timeSlot', new.time_slot,
      'binTypes', new.bin_types
    ));
  exception when others then
    -- never let a notification-dispatch failure block the pickup request itself
    raise warning 'notify_riders_on_new_pickup failed: %', sqlerrm;
  end;

  return new;
end;
$$;

-- ── Nobody nearby took it: widen the circle a step ─────────────────────────
create or replace function public.escalate_pickup_discovery()
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_row       public.pickup_requests;
  v_radius    numeric;
  v_max       numeric;
  v_wait      integer;
  v_previous  numeric;
  v_next      numeric;
  v_last_step boolean;
  v_rider_ids uuid[];
begin
  select coalesce(pickup_discovery_radius_km, 4),
         coalesce(pickup_discovery_max_radius_km, 12),
         coalesce(pickup_discovery_escalation_minutes, 3)
    into v_radius, v_max, v_wait
    from public.app_settings where id = true;

  v_radius := coalesce(v_radius, 4);
  v_max    := coalesce(v_max, 12);
  v_wait   := coalesce(v_wait, 3);

  for v_row in
    select * from public.pickup_requests
     where status = 'pending'
       and assigned_rider_id is null
       and location_lat is not null
       and location_lng is not null
       and discovery_notified_at is not null
       and discovery_notified_at <= now() - make_interval(mins => v_wait)
       and coalesce(discovery_radius_km, v_radius) < v_max
       -- A scheduled pickup whose slot has not started is not dispatched yet;
       -- dispatch_scheduled_pickup_alerts opens its circle when it becomes due.
       and (source <> 'scheduled' or (slot_starts_at is not null and slot_starts_at <= now()))
       -- Six hours of trying and still nobody: an admin problem, not a dispatch
       -- one. Measured from the last alert rather than creation, because a
       -- scheduled pickup is created days before anyone is told about it.
       and discovery_notified_at > now() - interval '6 hours'
     order by discovery_notified_at
     for update skip locked
  loop
    v_previous  := coalesce(v_row.discovery_radius_km, v_radius);
    v_next      := least(v_max, v_previous * 2);
    v_last_step := v_next >= v_max;

    -- Only the ring between the old and the new radius: a rider already
    -- alerted at the smaller radius is not rung again for the same job.
    v_rider_ids := public.riders_near(
      v_row.location_lat, v_row.location_lng, v_next,
      p_include_unlocated => v_last_step,
      p_min_radius_km => v_previous
    );

    update public.pickup_requests
       set discovery_radius_km = v_next,
           discovery_notified_at = now()
     where id = v_row.id;

    if array_length(v_rider_ids, 1) is not null then
      perform public.push_to_riders(jsonb_build_object(
        'type', 'new_pickup_request',
        'riderIds', to_jsonb(v_rider_ids),
        'requestId', v_row.id,
        'customerId', v_row.customer_id,
        'customerName', v_row.customer_name,
        'location', v_row.location,
        'locationLat', v_row.location_lat,
        'locationLng', v_row.location_lng,
        'radiusKm', v_next,
        'timeSlot', v_row.time_slot,
        'binTypes', v_row.bin_types
      ));
    end if;
  end loop;
exception when others then
  raise warning 'escalate_pickup_discovery failed: %', sqlerrm;
end;
$$;

revoke execute on function public.escalate_pickup_discovery() from public, anon, authenticated;

-- ── A due scheduled pickup nobody claimed opens the same circle ────────────
-- Same body as 20260917120000_scheduled_pickups.sql, with one change: the
-- unclaimed branch now alerts the riders near that customer rather than the
-- whole fleet, and stamps the discovery columns so escalate_pickup_discovery
-- can widen it if nobody takes it.
create or replace function public.dispatch_scheduled_pickup_alerts()
returns void language plpgsql security definer set search_path = public as $$
declare
  v_pickup public.pickup_requests;
  v_group record;
  v_local_hour int := extract(hour from now() at time zone 'Africa/Accra');
  v_unclaimed int;
  v_unclaimed_ids uuid[];
  v_radius numeric;
  v_rider_ids uuid[];
begin
  select coalesce(pickup_discovery_radius_km, 4) into v_radius
    from public.app_settings where id = true;
  v_radius := coalesce(v_radius, 4);

  -- The slot has started: sound the alarm.
  for v_pickup in
    select * from public.pickup_requests
     where source = 'scheduled'
       and status in ('pending', 'accepted')
       and due_alert_sent_at is null
       and slot_starts_at <= now()
       and slot_starts_at > now() - interval '3 hours'
     order by slot_starts_at
     for update skip locked
  loop
    if v_pickup.status = 'accepted' then
      perform public.push_to_riders(jsonb_build_object(
        'type', 'scheduled_pickup_due',
        'riderIds', jsonb_build_array(v_pickup.assigned_rider_id),
        'requestId', v_pickup.id,
        'customerId', v_pickup.customer_id,
        'customerName', v_pickup.customer_name,
        'location', v_pickup.location,
        'timeSlot', v_pickup.time_slot,
        'binTypes', v_pickup.bin_types,
        'title', 'Scheduled pickup starts now',
        'body', coalesce(v_pickup.customer_name, 'Customer') || ' • ' || coalesce(v_pickup.location, '') || ' • ' || v_pickup.time_slot
      ));
      insert into public.rider_notifications (rider_id, title, message, type)
      values (v_pickup.assigned_rider_id, 'Scheduled pickup starts now',
              coalesce(v_pickup.customer_name, 'Customer') || ' at ' || coalesce(v_pickup.location, 'their address') ||
                ' (' || v_pickup.time_slot || ').',
              'scheduled_pickup');
      -- The customer hears their rider is on the way now, not when it was claimed.
      perform public.send_pickup_status_sms(v_pickup);
    else
      -- Nobody claimed it: alert the riders near that address, like a fresh
      -- request. Riders further out are reached only if this one goes begging.
      v_rider_ids := case
        when v_pickup.location_lat is null or v_pickup.location_lng is null then null
        else public.riders_near(v_pickup.location_lat, v_pickup.location_lng, v_radius)
      end;

      if v_pickup.location_lat is not null and v_pickup.location_lng is not null then
        update public.pickup_requests
           set discovery_radius_km = v_radius,
               discovery_notified_at = now()
         where id = v_pickup.id;
      end if;

      if v_rider_ids is null or array_length(v_rider_ids, 1) is not null then
        perform public.push_to_riders(jsonb_build_object(
          'type', 'new_pickup_request',
          'riderIds', case when v_rider_ids is null then null::jsonb else to_jsonb(v_rider_ids) end,
          'requestId', v_pickup.id,
          'customerId', v_pickup.customer_id,
          'customerName', v_pickup.customer_name,
          'location', v_pickup.location,
          'locationLat', v_pickup.location_lat,
          'locationLng', v_pickup.location_lng,
          'radiusKm', v_radius,
          'timeSlot', v_pickup.time_slot,
          'binTypes', v_pickup.bin_types
        ));
      end if;
    end if;

    update public.pickup_requests set due_alert_sent_at = now() where id = v_pickup.id;
  end loop;

  -- Evening before (from 18:00): tell riders what tomorrow holds. This one is a
  -- fleet-wide summary of many addresses rather than a job offer, so it is not
  -- distance-scoped.
  if v_local_hour >= 18 then
    for v_group in
      select assigned_rider_id as rider_id, count(*) as n, array_agg(id) as ids,
             string_agg(coalesce(customer_name, 'Customer') || ' (' || split_part(time_slot, ' - ', 1) || ')', ', ' order by slot_starts_at) as summary
        from public.pickup_requests
       where source = 'scheduled' and status = 'accepted'
         and scheduled_for = public.ghana_today() + 1
         and reminder_sent_at is null
       group by assigned_rider_id
    loop
      perform public.push_to_riders(jsonb_build_object(
        'type', 'scheduled_pickup_reminder',
        'riderIds', jsonb_build_array(v_group.rider_id),
        'title', 'Tomorrow: ' || v_group.n || ' scheduled pickup' || case when v_group.n = 1 then '' else 's' end,
        'body', v_group.summary
      ));
      insert into public.rider_notifications (rider_id, title, message, type)
      values (v_group.rider_id,
              'Tomorrow: ' || v_group.n || ' scheduled pickup' || case when v_group.n = 1 then '' else 's' end,
              v_group.summary, 'scheduled_pickup');
      update public.pickup_requests set reminder_sent_at = now() where id = any (v_group.ids);
    end loop;

    select count(*), array_agg(id) into v_unclaimed, v_unclaimed_ids
      from public.pickup_requests
     where source = 'scheduled' and status = 'pending'
       and scheduled_for = public.ghana_today() + 1
       and reminder_sent_at is null;

    if v_unclaimed > 0 then
      perform public.push_to_riders(jsonb_build_object(
        'type', 'scheduled_pickup_reminder',
        'title', v_unclaimed || ' scheduled pickup' || case when v_unclaimed = 1 then '' else 's' end || ' tomorrow need a rider',
        'body', 'Open Upcoming pickups to claim one.'
      ));
      insert into public.rider_notifications (rider_id, title, message, type)
      select r.id,
             v_unclaimed || ' scheduled pickup' || case when v_unclaimed = 1 then '' else 's' end || ' tomorrow need a rider',
             'Open Upcoming pickups to claim one.', 'scheduled_pickup'
        from public.riders r
       where r.status in ('active', 'on_route', 'offline');
      update public.pickup_requests set reminder_sent_at = now() where id = any (v_unclaimed_ids);
    end if;
  end if;
end;
$$;

revoke execute on function public.dispatch_scheduled_pickup_alerts() from public, anon, authenticated;

-- ── Schedule ───────────────────────────────────────────────────────────────
select cron.unschedule(jobid) from cron.job where jobname = 'escalate-pickup-discovery';

select cron.schedule('escalate-pickup-discovery', '* * * * *',
  $$select public.escalate_pickup_discovery()$$);
