-- Company bike tracking.
--
-- Admins need to answer "where is this bike, who has it, and was it on a
-- pickup?" to catch company bikes being used for personal trips. Until now
-- the database could not: bikes had no identity (riders just carried the text
-- "Motorbike"), nothing recorded which rider had which bike, and only each
-- rider's latest position was kept, so there was no route history at all.
--
-- - vehicles gain a plate number and an assigned rider; vehicle_assignments
--   records every hand-over, maintained by trigger
-- - rider_location_pings keeps a thinned GPS trail (30 days), each point
--   tagged with the bike, the pickup in progress and the rider's duty status
-- - riders can see the bike assigned to them (the app tracks while they hold
--   one), and nothing else about the fleet

-- ── Bikes ──────────────────────────────────────────────────────────────────
alter table public.vehicles
  add column if not exists plate_number text,
  add column if not exists assigned_rider_id uuid references public.riders(id) on delete set null,
  add column if not exists assigned_at timestamptz;

create unique index if not exists vehicles_plate_number_key
  on public.vehicles (upper(btrim(plate_number)))
  where plate_number is not null;

-- One bike per rider at a time.
create unique index if not exists vehicles_one_per_rider_idx
  on public.vehicles (assigned_rider_id)
  where assigned_rider_id is not null;

drop policy if exists vehicles_select_assigned_rider on public.vehicles;
create policy vehicles_select_assigned_rider on public.vehicles
  for select using (assigned_rider_id = auth.uid());

-- ── Assignment history ─────────────────────────────────────────────────────
create table if not exists public.vehicle_assignments (
  id           uuid primary key default gen_random_uuid(),
  vehicle_id   uuid references public.vehicles(id) on delete set null,
  -- Snapshot, so history still reads sensibly after a bike is deleted.
  vehicle_label text,
  rider_id     uuid not null references public.riders(id) on delete cascade,
  assigned_at  timestamptz not null default now(),
  returned_at  timestamptz,
  assigned_by  uuid references public.profiles(id) on delete set null
);

create index if not exists vehicle_assignments_vehicle_idx
  on public.vehicle_assignments (vehicle_id, assigned_at desc);
create index if not exists vehicle_assignments_rider_idx
  on public.vehicle_assignments (rider_id, assigned_at desc);

alter table public.vehicle_assignments enable row level security;
drop policy if exists vehicle_assignments_all_admin on public.vehicle_assignments;
create policy vehicle_assignments_all_admin on public.vehicle_assignments
  for all using (public.is_admin()) with check (public.is_admin());

create or replace function public.track_vehicle_assignment()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' and new.assigned_rider_id is not distinct from old.assigned_rider_id then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.assigned_rider_id is not null then
    update public.vehicle_assignments
       set returned_at = now()
     where vehicle_id = new.id and returned_at is null;
  end if;

  if new.assigned_rider_id is not null then
    insert into public.vehicle_assignments (vehicle_id, vehicle_label, rider_id, assigned_by)
    values (
      new.id,
      coalesce(nullif(btrim(new.plate_number), ''), new.name),
      new.assigned_rider_id,
      auth.uid()
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_vehicles_track_assignment on public.vehicles;
create trigger trg_vehicles_track_assignment
  after insert or update of assigned_rider_id on public.vehicles
  for each row execute function public.track_vehicle_assignment();

create or replace function public.stamp_vehicle_assignment()
returns trigger language plpgsql as $$
begin
  if new.assigned_rider_id is distinct from (case when tg_op = 'UPDATE' then old.assigned_rider_id end) then
    new.assigned_at := case when new.assigned_rider_id is null then null else now() end;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_vehicles_stamp_assignment on public.vehicles;
create trigger trg_vehicles_stamp_assignment
  before insert or update of assigned_rider_id on public.vehicles
  for each row execute function public.stamp_vehicle_assignment();

-- Assign a bike, moving the rider off any bike they already hold.
create or replace function public.admin_assign_vehicle(p_vehicle_id uuid, p_rider_id uuid)
returns public.vehicles
language plpgsql security definer set search_path = public as $$
declare
  v_vehicle public.vehicles;
begin
  if not public.is_admin() then
    raise exception 'Only admins can assign bikes.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_vehicle from public.vehicles where id = p_vehicle_id for update;
  if not found then
    raise exception 'Bike not found.';
  end if;

  if p_rider_id is not null then
    update public.vehicles
       set assigned_rider_id = null
     where assigned_rider_id = p_rider_id and id <> p_vehicle_id;
  end if;

  update public.vehicles
     set assigned_rider_id = p_rider_id
   where id = p_vehicle_id
  returning * into v_vehicle;

  return v_vehicle;
end;
$$;

-- ── Location trail ─────────────────────────────────────────────────────────
create table if not exists public.rider_location_pings (
  id                 bigint generated always as identity primary key,
  rider_id           uuid not null references public.riders(id) on delete cascade,
  vehicle_id         uuid references public.vehicles(id) on delete set null,
  pickup_request_id  uuid references public.pickup_requests(id) on delete set null,
  rider_status       text,
  lat                double precision not null,
  lng                double precision not null,
  heading            double precision,
  speed              double precision,
  recorded_at        timestamptz not null default now()
);

comment on table public.rider_location_pings is
  'Thinned GPS trail written by update_rider_location: a point when the rider moves 30 m+ (at most every 15 s) or every 2 minutes when parked. Kept 30 days.';

create index if not exists rider_location_pings_rider_idx
  on public.rider_location_pings (rider_id, recorded_at desc);
create index if not exists rider_location_pings_vehicle_idx
  on public.rider_location_pings (vehicle_id, recorded_at desc)
  where vehicle_id is not null;
create index if not exists rider_location_pings_pickup_idx
  on public.rider_location_pings (pickup_request_id, recorded_at)
  where pickup_request_id is not null;
create index if not exists rider_location_pings_recorded_idx
  on public.rider_location_pings (recorded_at);

alter table public.rider_location_pings enable row level security;
drop policy if exists rider_location_pings_select_admin on public.rider_location_pings;
create policy rider_location_pings_select_admin on public.rider_location_pings
  for select using (public.is_admin());

-- ── update_rider_location: also append to the trail ────────────────────────
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
  v_status text;
  v_job uuid;
  v_vehicle uuid;
  v_last public.rider_location_pings;
  v_moved_m double precision;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to update location.';
  end if;

  if p_lat is null or p_lng is null or abs(p_lat) > 90 or abs(p_lng) > 180 then
    raise exception 'Invalid coordinates.';
  end if;

  update public.riders
     set current_lat = p_lat,
         current_lng = p_lng,
         heading = coalesce(p_heading, 0),
         speed = coalesce(p_speed, 0),
         last_location_update = now()
   where id = v_rider_id
  returning status into v_status;

  if not found then
    raise exception 'Must be signed in as a rider to update location.';
  end if;

  if p_current_job_id is not null then
    update public.pickup_requests
       set rider_lat = p_lat,
           rider_lng = p_lng,
           rider_heading = coalesce(p_heading, 0),
           rider_speed = coalesce(p_speed, 0),
           rider_location_updated_at = now()
     where id = p_current_job_id
       and assigned_rider_id = v_rider_id
       and status = 'accepted';
    if found then
      v_job := p_current_job_id;
    end if;
  end if;

  -- The app only knows its job while the navigation screen is open; the rider
  -- is still on that pickup after closing it.
  if v_job is null then
    select id into v_job
      from public.pickup_requests
     where assigned_rider_id = v_rider_id and status = 'accepted'
     order by accepted_at desc nulls last
     limit 1;
  end if;

  select id into v_vehicle from public.vehicles where assigned_rider_id = v_rider_id;

  select * into v_last
    from public.rider_location_pings
   where rider_id = v_rider_id
   order by recorded_at desc
   limit 1;

  if v_last.id is not null then
    v_moved_m := 111320 * sqrt(
      power(p_lat - v_last.lat, 2) +
      power((p_lng - v_last.lng) * cos(radians((p_lat + v_last.lat) / 2)), 2));
  end if;

  if v_last.id is null
     or v_last.pickup_request_id is distinct from v_job
     or v_last.vehicle_id is distinct from v_vehicle
     or v_last.rider_status is distinct from v_status
     or now() - v_last.recorded_at >= interval '2 minutes'
     or (now() - v_last.recorded_at >= interval '15 seconds' and v_moved_m >= 30) then
    insert into public.rider_location_pings
      (rider_id, vehicle_id, pickup_request_id, rider_status, lat, lng, heading, speed)
    values
      (v_rider_id, v_vehicle, v_job, v_status, p_lat, p_lng, p_heading, p_speed);
  end if;
end;
$$;

-- ── Pickup lookup for the fleet map search ─────────────────────────────────
-- Pickup IDs are shown as the first 8 characters of the uuid ("#6E94935B"),
-- which PostgREST filters cannot match against a uuid column. Security
-- invoker: pickup_requests RLS already limits this to admins.
create or replace function public.admin_find_pickups(p_query text, p_limit int default 8)
returns setof public.pickup_requests
language sql stable security invoker set search_path = public as $$
  with q as (
    select lower(regexp_replace(btrim(coalesce(p_query, '')), '^#', '')) as term
  )
  select pr.*
    from public.pickup_requests pr, q
   where length(q.term) >= 3
     and (
       replace(pr.id::text, '-', '') like replace(q.term, '-', '') || '%'
       or lower(coalesce(pr.customer_name, '')) like '%' || q.term || '%'
       or lower(coalesce(pr.assigned_rider_name, '')) like '%' || q.term || '%'
       or lower(coalesce(pr.location, '')) like '%' || q.term || '%'
     )
   order by pr.created_at desc
   limit least(greatest(coalesce(p_limit, 8), 1), 50);
$$;

-- ── Retention: 30 days of trail ────────────────────────────────────────────
create extension if not exists pg_cron;

select cron.unschedule(jobid)
  from cron.job
 where jobname = 'purge-rider-location-pings';

select cron.schedule(
  'purge-rider-location-pings',
  '30 2 * * *',
  $$delete from public.rider_location_pings where recorded_at < now() - interval '30 days'$$
);
