-- Recurring pickups for subscription customers.
--
-- A customer on a subscription picks their collection day(s) per bin, but
-- still had to open the app and request every single pickup. Now a paid
-- subscription produces those pickups on its own:
--
--   * A plan name is how long the customer has paid for: Weekly = 7 days,
--     Bi-Weekly = 14 days, Monthly = 1 month. Pickups happen every week on the
--     chosen day(s) until that paid period ends.
--   * Cover is recorded server-side from verified Paystack payments
--     (grant_subscription_period, called by verify-paystack-transaction) in
--     subscription_periods / customers.subscription_paid_until. Customers
--     cannot extend it themselves, which closes the hole where registering a
--     bin (or editing the customers row) switched on a plan for free.
--   * generate_scheduled_pickups creates the next 3 days of pickups for covered
--     customers. Any rider can claim one ahead of time, or release it again.
--   * dispatch_scheduled_pickup_alerts reminds riders the evening before
--     (18:00) and sounds the alarm when the slot starts: the claiming rider,
--     or every rider if nobody has claimed it.
--
-- Ghana (Africa/Accra) is UTC+0 with no daylight saving, so calendar dates and
-- slot times below are Ghana time.

-- ── Subscription cover ─────────────────────────────────────────────────────
alter table public.customers
  add column if not exists subscription_paid_until timestamptz,
  add column if not exists subscription_started_at timestamptz;

comment on column public.customers.subscription_paid_until is
  'End of the paid subscription period. Written only by grant_subscription_period (verified payments). Null or past means no cover.';

create table if not exists public.subscription_periods (
  id                 uuid primary key default gen_random_uuid(),
  customer_id        uuid not null references public.customers(id) on delete cascade,
  plan_name          text not null,
  amount             numeric(10,2) not null,
  payment_reference  text not null unique,
  starts_at          timestamptz not null,
  ends_at            timestamptz not null,
  created_at         timestamptz not null default now()
);

create index if not exists subscription_periods_customer_idx
  on public.subscription_periods (customer_id, ends_at desc);

alter table public.subscription_periods enable row level security;
drop policy if exists subscription_periods_select_own on public.subscription_periods;
create policy subscription_periods_select_own on public.subscription_periods
  for select using (customer_id = auth.uid());
drop policy if exists subscription_periods_all_admin on public.subscription_periods;
create policy subscription_periods_all_admin on public.subscription_periods
  for all using (public.is_admin()) with check (public.is_admin());

/** Length of one paid period for a plan's frequency. */
create or replace function public.plan_period(p_frequency text)
returns interval language sql immutable as $$
  select case lower(regexp_replace(coalesce(p_frequency, ''), '[^a-zA-Z]', '', 'g'))
    when 'weekly' then interval '7 days'
    when 'biweekly' then interval '14 days'
    else interval '1 month'
  end;
$$;

-- Called with the service role once Paystack has confirmed the charge.
-- Idempotent per payment reference; a renewal extends from the end of the
-- current cover instead of overlapping it.
create or replace function public.grant_subscription_period(
  p_customer_id uuid,
  p_plan_name text,
  p_amount numeric,
  p_reference text,
  p_paid_at timestamptz default now()
)
returns public.subscription_periods
language plpgsql security definer set search_path = public as $$
declare
  v_plan public.pricing_plans;
  v_customer public.customers;
  v_period public.subscription_periods;
  v_start timestamptz;
begin
  select * into v_period from public.subscription_periods where payment_reference = p_reference;
  if found then
    return v_period;
  end if;

  select * into v_plan from public.pricing_plans where lower(name) = lower(btrim(p_plan_name)) limit 1;
  if not found or v_plan.is_payg then
    raise exception 'Not a subscription plan: %', p_plan_name;
  end if;

  select * into v_customer from public.customers where id = p_customer_id for update;
  if not found then
    raise exception 'Customer not found.';
  end if;

  v_start := greatest(coalesce(p_paid_at, now()), coalesce(v_customer.subscription_paid_until, '-infinity'::timestamptz));

  insert into public.subscription_periods (customer_id, plan_name, amount, payment_reference, starts_at, ends_at)
  values (p_customer_id, v_plan.name, coalesce(p_amount, 0), p_reference, v_start, v_start + public.plan_period(v_plan.frequency))
  returning * into v_period;

  update public.customers
     set subscription_plan_name = v_plan.name,
         subscription_plan_id = v_plan.id,
         subscription_fee = coalesce(p_amount, subscription_fee),
         subscription_status = 'active',
         subscription_paid_until = v_period.ends_at,
         subscription_started_at = case
           when subscription_paid_until is null or subscription_paid_until <= now() then v_period.starts_at
           else subscription_started_at end,
         last_payment_reference = p_reference
   where id = p_customer_id;

  -- Put the new cover to use straight away rather than at the next cron run.
  perform public.generate_scheduled_pickups();

  return v_period;
end;
$$;

-- Customers may still switch their plan label (the app does after paying),
-- but never the cover, the fee commission is based on, or the status.
create or replace function public.guard_customer_subscription()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    new.subscription_paid_until := old.subscription_paid_until;
    new.subscription_started_at := old.subscription_started_at;
    new.subscription_fee := old.subscription_fee;
    new.subscription_status := old.subscription_status;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_customers_guard_subscription on public.customers;
create trigger trg_customers_guard_subscription
  before update on public.customers
  for each row execute function public.guard_customer_subscription();

-- No cover, no free pickups -- whatever the plan label says.
create or replace function public.sync_subscription_is_payg()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_is_payg boolean;
begin
  select p.is_payg into v_is_payg
    from public.pricing_plans p
   where lower(p.name) = lower(new.subscription_plan_name)
   limit 1;

  new.subscription_is_payg :=
    coalesce(v_is_payg, true)
    or new.subscription_status <> 'active'
    or new.subscription_paid_until is null
    or new.subscription_paid_until <= now();

  return new;
end;
$$;

drop trigger if exists trg_customers_sync_payg on public.customers;
create trigger trg_customers_sync_payg
  before insert or update of subscription_plan_name, subscription_status, subscription_paid_until
  on public.customers
  for each row execute function public.sync_subscription_is_payg();

-- Recompute for everyone under the new rule (no customer has paid cover yet).
update public.customers c
   set subscription_is_payg = coalesce(
         (select p.is_payg from public.pricing_plans p where lower(p.name) = lower(c.subscription_plan_name) limit 1),
         true)
       or c.subscription_status <> 'active'
       or c.subscription_paid_until is null
       or c.subscription_paid_until <= now();

-- Registering a bin no longer switches the customer onto a plan.
drop function if exists public.register_bin(text, text, text, text, text[], text, text);

create or replace function public.register_bin(
  p_serial_number text,
  p_type text,
  p_size text,
  p_frequency text,
  p_pickup_days text[],
  p_gps_location text,
  p_photo_path text default null,
  p_time_slot text default null
)
returns public.bins
language plpgsql as $$
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
    fill_level_percentage, schedule_frequency, pickup_days, pickup_time_slot, gps_location, verification_photo_url
  )
  values (
    v_customer_id, p_serial_number, p_type, p_size, 'personal', 'active',
    0, p_frequency, p_pickup_days, coalesce(p_time_slot, '08:00 AM - 12:00 PM'), p_gps_location, p_photo_path
  )
  returning * into v_bin;

  update public.customers
     set registered_bins_count = registered_bins_count + 1,
         contract_type = 'Residential'
   where id = v_customer_id;

  insert into public.admin_notifications (title, message, type, customer_id, customer_name)
  values ('New Bin Registered', v_customer_name || ' registered a ' || p_size || ' ' || p_type || ' bin.',
          'bin_registered', v_customer_id, v_customer_name);

  return v_bin;
end;
$$;

-- ── Commission value of a subscription pickup ──────────────────────────────
-- A paid period covers (weeks in the period) x (pickup days per week) pickups.
create or replace function public.subscription_pickup_value(p_customer_id uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select round(
    coalesce(
      nullif(c.subscription_fee, 0),
      (p.prices ->> coalesce(
        (select b.size from public.bins b where b.customer_id = c.id order by b.registered_at limit 1),
        '240L'))::numeric,
      0
    )
    / greatest(1, round(
        extract(epoch from public.plan_period(p.frequency)) / 604800.0
        * greatest(1, (
            select count(distinct lower(btrim(d)))
              from public.bins b, unnest(coalesce(b.pickup_days, '{}')) d
             where b.customer_id = c.id and coalesce(b.status, 'active') = 'active'
          ))
      )),
    2)
  from public.customers c
  left join public.pricing_plans p on lower(p.name) = lower(c.subscription_plan_name)
  where c.id = p_customer_id;
$$;

revoke execute on function public.subscription_pickup_value(uuid) from public, anon, authenticated;
revoke execute on function public.grant_subscription_period(uuid, text, numeric, text, timestamptz) from public, anon, authenticated;

update public.pricing_plans set description = 'One week of collections on your chosen day(s)'
 where slug = 'weekly' and description = 'Collection once every week';
update public.pricing_plans set description = 'Two weeks of collections on your chosen day(s)'
 where slug = 'biweekly' and description = 'Collection once every two weeks';
update public.pricing_plans set description = 'One month of collections on your chosen day(s)'
 where slug = 'monthly' and description = 'Collection once every month';

-- ── The customer's schedule ────────────────────────────────────────────────
alter table public.bins
  add column if not exists pickup_time_slot text not null default '08:00 AM - 12:00 PM';

alter table public.bins drop constraint if exists bins_pickup_time_slot_check;
alter table public.bins add constraint bins_pickup_time_slot_check
  check (pickup_time_slot in ('08:00 AM - 12:00 PM', '12:00 PM - 04:00 PM'));

drop function if exists public.customer_update_bin(uuid, text, text[]);

create or replace function public.customer_update_bin(
  p_bin_id uuid,
  p_frequency text,
  p_pickup_days text[],
  p_time_slot text default null
)
returns public.bins
-- Security definer so it can refresh the generated pickups; ownership is
-- enforced by the customer_id / ownership guard on the update below.
language plpgsql security definer set search_path = public as $$
declare
  v_customer_id uuid := auth.uid();
  v_bin public.bins;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to update a bin.';
  end if;

  if p_time_slot is not null and p_time_slot not in ('08:00 AM - 12:00 PM', '12:00 PM - 04:00 PM') then
    raise exception 'Choose a morning (8 AM–12 PM) or afternoon (12–4 PM) slot.';
  end if;

  update public.bins
     set schedule_frequency = p_frequency,
         pickup_days = p_pickup_days,
         pickup_time_slot = coalesce(p_time_slot, pickup_time_slot)
   where id = p_bin_id
     and customer_id = v_customer_id
     and ownership = 'personal'
  returning * into v_bin;

  if not found then
    raise exception 'Bin not found or is not editable.';
  end if;

  -- Move upcoming scheduled pickups onto the new day/slot now.
  perform public.generate_scheduled_pickups();

  return v_bin;
end;
$$;

-- ── Scheduled pickups ──────────────────────────────────────────────────────
alter table public.pickup_requests
  add column if not exists source text not null default 'on_demand',
  add column if not exists scheduled_for date,
  add column if not exists slot_starts_at timestamptz,
  add column if not exists reminder_sent_at timestamptz,
  add column if not exists due_alert_sent_at timestamptz;

alter table public.pickup_requests drop constraint if exists pickup_requests_source_check;
alter table public.pickup_requests add constraint pickup_requests_source_check
  check (source in ('on_demand', 'scheduled'));

comment on column public.pickup_requests.slot_starts_at is
  'When the pickup''s time slot begins. Set for scheduled pickups; drives the reminder and the alarm.';

-- One scheduled pickup per customer, day and slot -- also stops a cancelled
-- (skipped) one from being recreated.
create unique index if not exists pickup_requests_scheduled_unique_idx
  on public.pickup_requests (customer_id, scheduled_for, time_slot)
  where source = 'scheduled';

create index if not exists pickup_requests_scheduled_open_idx
  on public.pickup_requests (slot_starts_at)
  where source = 'scheduled' and status in ('pending', 'accepted');

create or replace function public.slot_start(p_day date, p_time_slot text)
returns timestamptz language sql immutable as $$
  select ((p_day::text || ' ' || split_part(p_time_slot, ' - ', 1))::timestamp) at time zone 'Africa/Accra';
$$;

create or replace function public.ghana_today()
returns date language sql stable as $$
  select (now() at time zone 'Africa/Accra')::date;
$$;

create or replace function public.generate_scheduled_pickups(p_days_ahead int default 3)
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_created int;
begin
  -- Withdraw open scheduled pickups that no longer have cover or no longer
  -- match any bin's day and slot (the customer changed their schedule).
  update public.pickup_requests pr
     set status = 'cancelled',
         completion_notes = 'Withdrawn: no longer covered by the customer''s subscription or schedule.'
    from public.customers c
   where pr.customer_id = c.id
     and pr.source = 'scheduled'
     and pr.status in ('pending', 'accepted')
     and pr.slot_starts_at > now()
     and (
       c.subscription_is_payg
       or c.subscription_paid_until is null
       or pr.slot_starts_at >= c.subscription_paid_until
       or not exists (
         select 1 from public.bins b, unnest(coalesce(b.pickup_days, '{}')) d
          where b.customer_id = c.id
            and coalesce(b.status, 'active') = 'active'
            and b.pickup_time_slot = pr.time_slot
            and lower(btrim(d)) = lower(trim(to_char(pr.scheduled_for, 'FMDay')))
       )
     );

  with days as (
    select (public.ghana_today() + g)::date as day
      from generate_series(0, greatest(0, least(coalesce(p_days_ahead, 3), 14))) g
  ),
  wanted as (
    select b.customer_id, d.day, b.pickup_time_slot as time_slot,
           array_agg(distinct b.type order by b.type) as bin_types,
           (array_agg(b.gps_location order by b.registered_at))[1] as bin_gps
      from public.bins b
      join public.customers c on c.id = b.customer_id
      cross join days d
     where coalesce(b.status, 'active') = 'active'
       and not c.subscription_is_payg
       and c.subscription_status = 'active'
       and c.subscription_paid_until is not null
       and exists (
         select 1 from unnest(coalesce(b.pickup_days, '{}')) pd
          where lower(btrim(pd)) = lower(trim(to_char(d.day, 'FMDay')))
       )
     group by b.customer_id, d.day, b.pickup_time_slot
  ),
  inserted as (
    insert into public.pickup_requests (
      customer_id, customer_name, customer_email, customer_phone,
      bin_types, date, time_slot, location, location_lat, location_lng, house_photo_url,
      instructions, status, payment_status, payment_method, amount_paid, original_amount,
      service_value, source, scheduled_for, slot_starts_at
    )
    select
      w.customer_id, p.full_name, p.email, p.phone_number,
      w.bin_types, public.slot_start(w.day, w.time_slot), w.time_slot,
      coalesce(a.address, w.bin_gps, p.address, 'Customer address'),
      coalesce(a.latitude, (substring(w.bin_gps from '(-?\d{1,3}\.\d+)\s*,\s*-?\d{1,3}\.\d+'))::double precision),
      coalesce(a.longitude, (substring(w.bin_gps from '-?\d{1,3}\.\d+\s*,\s*(-?\d{1,3}\.\d+)'))::double precision),
      c.house_photo_url,
      'Scheduled pickup — ' || c.subscription_plan_name,
      'pending', 'paid', 'Covered by ' || c.subscription_plan_name, 0, 0,
      public.subscription_pickup_value(w.customer_id), 'scheduled', w.day, public.slot_start(w.day, w.time_slot)
    from wanted w
    join public.customers c on c.id = w.customer_id
    join public.profiles p on p.id = w.customer_id
    left join lateral (
      select ca.address, ca.latitude, ca.longitude
        from public.customer_addresses ca
       where ca.customer_id = w.customer_id and ca.latitude is not null
       order by ca.is_default desc, ca.created_at
       limit 1
    ) a on true
    where public.slot_start(w.day, w.time_slot) > now()
      and public.slot_start(w.day, w.time_slot) < c.subscription_paid_until
    on conflict (customer_id, scheduled_for, time_slot) where source = 'scheduled' do nothing
    returning customer_id
  )
  select count(*) into v_created from inserted;

  -- Keep the customer's "next pickup" card pointing at the soonest one.
  update public.customers c
     set next_pickup_date = n.slot_starts_at,
         next_pickup_time_slot = n.time_slot,
         next_pickup_bin_types = n.bin_types
    from (
      select distinct on (customer_id) customer_id, slot_starts_at, time_slot, bin_types
        from public.pickup_requests
       where source = 'scheduled' and status in ('pending', 'accepted') and slot_starts_at > now()
       order by customer_id, slot_starts_at
    ) n
   where c.id = n.customer_id
     and (c.next_pickup_date is null or c.next_pickup_date < now() or c.next_pickup_date > n.slot_starts_at);

  return v_created;
end;
$$;

revoke execute on function public.generate_scheduled_pickups(int) from public, anon, authenticated;

-- ── Riders: claiming ahead, releasing, capacity ────────────────────────────
-- A pickup claimed for later in the week must not use up the "active pickups
-- at once" limit, but a rider cannot hoard every upcoming pickup either.
create or replace function public.accept_pickup(p_request_id uuid)
returns public.pickup_requests
language plpgsql security definer set search_path = public as $$
declare
  v_rider_id uuid := auth.uid();
  v_rider_name text;
  v_row public.pickup_requests;
  v_target public.pickup_requests;
  v_limit integer;
  v_active_count integer;
  v_upcoming_count integer;
  v_upcoming_limit constant integer := 10;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to accept a pickup.';
  end if;

  select * into v_target from public.pickup_requests where id = p_request_id;

  select max_concurrent_pickups into v_limit from public.app_settings where id = true;
  v_limit := coalesce(v_limit, 3);

  if v_target.source = 'scheduled' and v_target.slot_starts_at > now() + interval '1 hour' then
    select count(*) into v_upcoming_count
      from public.pickup_requests
     where assigned_rider_id = v_rider_id and status = 'accepted'
       and source = 'scheduled' and slot_starts_at > now() + interval '1 hour';
    if v_upcoming_count >= v_upcoming_limit then
      raise exception 'You have already claimed % upcoming pickups. Release one before claiming another.', v_upcoming_limit;
    end if;
  else
    select count(*) into v_active_count
      from public.pickup_requests
     where assigned_rider_id = v_rider_id and status = 'accepted'
       and not (source = 'scheduled' and slot_starts_at > now() + interval '1 hour');
    if v_active_count >= v_limit then
      raise exception 'You already have % active pickup(s) — the maximum allowed at once. Complete one before accepting another.', v_limit;
    end if;
  end if;

  select full_name into v_rider_name from public.profiles where id = v_rider_id;

  update public.pickup_requests
     set status = 'accepted', assigned_rider_id = v_rider_id,
         assigned_rider_name = v_rider_name, accepted_at = now()
   where id = p_request_id and status = 'pending'
  returning * into v_row;

  if not found then
    raise exception 'This pickup was already accepted by another rider.';
  end if;

  insert into public.admin_notifications (title, message, type, rider_id, rider_name, request_id, customer_id)
  values (
    case when v_row.source = 'scheduled' then 'Scheduled Pickup Claimed' else 'Pickup Accepted' end,
    v_rider_name || case when v_row.source = 'scheduled'
      then ' claimed the scheduled pickup for ' || coalesce(v_row.customer_name, 'a customer') ||
           ' on ' || to_char(v_row.slot_starts_at at time zone 'Africa/Accra', 'FMDy DD Mon, HH12:MI AM') || '.'
      else ' accepted a pickup request.' end,
    'pickup_accepted', v_rider_id, v_rider_name, p_request_id, v_row.customer_id);

  return v_row;
end;
$$;

create or replace function public.release_pickup(p_request_id uuid)
returns public.pickup_requests
language plpgsql security definer set search_path = public as $$
declare
  v_rider_id uuid := auth.uid();
  v_row public.pickup_requests;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to release a pickup.';
  end if;

  update public.pickup_requests
     set status = 'pending', assigned_rider_id = null, assigned_rider_name = null, accepted_at = null
   where id = p_request_id
     and assigned_rider_id = v_rider_id
     and status = 'accepted'
     and source = 'scheduled'
     and slot_starts_at > now()
  returning * into v_row;

  if not found then
    raise exception 'Only a scheduled pickup you claimed can be released, and only before its time slot starts.';
  end if;

  insert into public.admin_notifications (title, message, type, rider_id, request_id, customer_id)
  values ('Scheduled Pickup Released',
          coalesce((select full_name from public.profiles where id = v_rider_id), 'A rider') ||
            ' released the scheduled pickup for ' || coalesce(v_row.customer_name, 'a customer') || '.',
          'pickup_released', v_rider_id, v_row.id, v_row.customer_id);

  return v_row;
end;
$$;

-- The trail must not be tagged with a pickup claimed for later in the week.
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

  if v_job is null then
    select id into v_job
      from public.pickup_requests
     where assigned_rider_id = v_rider_id and status = 'accepted'
       and (source = 'on_demand' or slot_starts_at <= now() + interval '30 minutes')
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

-- ── Notifications ──────────────────────────────────────────────────────────
-- Scheduled pickups are announced by the dispatcher at the right moments, not
-- the instant they are generated days ahead.
create or replace function public.notify_riders_on_new_pickup()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_secret text;
begin
  if new.status <> 'pending' or new.source = 'scheduled' then
    return new;
  end if;

  begin
    select decrypted_secret into v_secret
      from vault.decrypted_secrets
     where name = 'pickup_webhook_secret';

    if v_secret is not null then
      perform net.http_post(
        url := 'https://mfysompctaxldphbxvkv.supabase.co/functions/v1/notify-riders-on-new-pickup',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', v_secret),
        body := jsonb_build_object(
          'requestId', new.id,
          'customerId', new.customer_id,
          'customerName', new.customer_name,
          'location', new.location,
          'timeSlot', new.time_slot,
          'binTypes', new.bin_types
        )
      );
    end if;
  exception when others then
    -- never let a notification-dispatch failure block the pickup request itself
    raise warning 'notify_riders_on_new_pickup failed: %', sqlerrm;
  end;

  return new;
end;
$$;

-- "Rider X accepted your pickup and is on the way" is wrong three days early;
-- for a scheduled pickup that SMS goes out when the slot starts instead.
create or replace function public.notify_customer_on_pickup_status_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_secret text;
  v_phone text;
  v_customer_name text;
begin
  if new.status not in ('accepted', 'completed') then
    return new;
  end if;

  if new.status = 'accepted' and new.source = 'scheduled' and new.slot_starts_at > now() then
    return new;
  end if;

  perform public.send_pickup_status_sms(new);
  return new;
end;
$$;

create or replace function public.send_pickup_status_sms(p_row public.pickup_requests)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_secret text;
  v_phone text;
  v_customer_name text;
begin
  select phone_number, full_name into v_phone, v_customer_name
    from public.profiles where id = p_row.customer_id;

  if v_phone is null or v_phone = '' then
    return;
  end if;

  select decrypted_secret into v_secret
    from vault.decrypted_secrets
   where name = 'pickup_status_sms_webhook_secret';

  if v_secret is not null then
    perform net.http_post(
      url := 'https://mfysompctaxldphbxvkv.supabase.co/functions/v1/notify-pickup-status-sms',
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', v_secret),
      body := jsonb_build_object(
        'requestId', p_row.id,
        'customerId', p_row.customer_id,
        'customerName', v_customer_name,
        'phoneNumber', v_phone,
        'status', p_row.status,
        'riderName', p_row.assigned_rider_name,
        'timeSlot', p_row.time_slot,
        'location', p_row.location,
        'weightKg', p_row.actual_weight_kg
      )
    );
  end if;
exception when others then
  -- never let a notification-dispatch failure block the transition itself
  raise warning 'send_pickup_status_sms failed: %', sqlerrm;
end;
$$;

revoke execute on function public.send_pickup_status_sms(public.pickup_requests) from public, anon, authenticated;

create or replace function public.push_to_riders(p_payload jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
    from vault.decrypted_secrets
   where name = 'pickup_webhook_secret';

  if v_secret is not null then
    perform net.http_post(
      url := 'https://mfysompctaxldphbxvkv.supabase.co/functions/v1/notify-riders-on-new-pickup',
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', v_secret),
      body := p_payload
    );
  end if;
exception when others then
  raise warning 'push_to_riders failed: %', sqlerrm;
end;
$$;

revoke execute on function public.push_to_riders(jsonb) from public, anon, authenticated;

create or replace function public.dispatch_scheduled_pickup_alerts()
returns void language plpgsql security definer set search_path = public as $$
declare
  v_pickup public.pickup_requests;
  v_group record;
  v_local_hour int := extract(hour from now() at time zone 'Africa/Accra');
  v_unclaimed int;
  v_unclaimed_ids uuid[];
begin
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
      -- Nobody claimed it: alert every rider like a fresh request.
      perform public.push_to_riders(jsonb_build_object(
        'type', 'new_pickup_request',
        'requestId', v_pickup.id,
        'customerId', v_pickup.customer_id,
        'customerName', v_pickup.customer_name,
        'location', v_pickup.location,
        'timeSlot', v_pickup.time_slot,
        'binTypes', v_pickup.bin_types
      ));
    end if;

    update public.pickup_requests set due_alert_sent_at = now() where id = v_pickup.id;
  end loop;

  -- Evening before (from 18:00): tell riders what tomorrow holds.
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

-- ── Schedules ──────────────────────────────────────────────────────────────
create extension if not exists pg_cron;

select cron.unschedule(jobid) from cron.job
 where jobname in ('generate-scheduled-pickups', 'dispatch-scheduled-pickup-alerts', 'expire-subscriptions');

select cron.schedule('generate-scheduled-pickups', '*/30 * * * *',
  $$select public.generate_scheduled_pickups()$$);

select cron.schedule('dispatch-scheduled-pickup-alerts', '*/5 * * * *',
  $$select public.dispatch_scheduled_pickup_alerts()$$);

-- Cover that has run out flips the customer back to paying per pickup.
select cron.schedule('expire-subscriptions', '*/15 * * * *',
  $$update public.customers set subscription_status = 'inactive'
     where subscription_status = 'active'
       and subscription_paid_until is not null
       and subscription_paid_until <= now()$$);
