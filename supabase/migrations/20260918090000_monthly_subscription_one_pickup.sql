-- A Monthly Plan covers one customer-chosen pickup in each paid subscription
-- period. It is not a month of unlimited requests or weekly auto-generated
-- collections. The server owns this rule so it cannot be bypassed from an
-- altered client build.

-- A non-null value records the one request that consumed a monthly paid
-- period. The unique index below intentionally remains in force after a
-- customer cancels: a paid monthly period permits one request, not repeated
-- rebooking attempts.
alter table public.pickup_requests
  add column if not exists monthly_subscription_period_id uuid
  references public.subscription_periods(id) on delete set null;

comment on column public.pickup_requests.monthly_subscription_period_id is
  'The verified Monthly subscription period consumed by this pickup request. One request is allowed per period.';

-- Do not leave auto-generated Monthly pickups in front of customers after the
-- rule changes. A claimed/assigned pickup is left alone because it is already
-- an operational commitment; it is backfilled below and counts as the period''s
-- one request.
with withdrawn as (
  update public.pickup_requests pr
     set status = 'cancelled',
         completion_notes = 'Withdrawn: Monthly plans require the customer to choose one pickup date.',
         updated_at = now()
    from public.subscription_periods sp
    join public.pricing_plans plan on lower(plan.name) = lower(sp.plan_name)
   where pr.customer_id = sp.customer_id
     and pr.source = 'scheduled'
     and pr.status in ('pending', 'accepted')
     and pr.slot_starts_at > now()
     and pr.slot_starts_at >= sp.starts_at
     and pr.slot_starts_at < sp.ends_at
     and lower(regexp_replace(coalesce(plan.frequency, ''), '[^a-zA-Z]', '', 'g')) = 'monthly'
  returning pr.customer_id, pr.date
)
update public.customers c
   set next_pickup_date = null,
       next_pickup_time_slot = null,
       next_pickup_bin_types = null
  from withdrawn w
 where c.id = w.customer_id
   and c.next_pickup_date = w.date;

-- Preserve the history of a Monthly pickup already made under the old logic.
-- If old data contains several requests in one period, the earliest one is the
-- entitlement record; later historical rows remain visible but cannot create a
-- second request going forward.
with ranked_monthly_requests as (
  select
    pr.id,
    sp.id as subscription_period_id,
    row_number() over (
      partition by sp.id
      order by pr.date, pr.created_at, pr.id
    ) as request_number
    from public.pickup_requests pr
    join public.subscription_periods sp
      on sp.customer_id = pr.customer_id
     and pr.date >= sp.starts_at
     and pr.date < sp.ends_at
    join public.pricing_plans plan on lower(plan.name) = lower(sp.plan_name)
   where pr.monthly_subscription_period_id is null
     and pr.status <> 'cancelled'
     and lower(regexp_replace(coalesce(plan.frequency, ''), '[^a-zA-Z]', '', 'g')) = 'monthly'
)
update public.pickup_requests pr
   set monthly_subscription_period_id = ranked.subscription_period_id
  from ranked_monthly_requests ranked
 where pr.id = ranked.id
   and ranked.request_number = 1;

create unique index if not exists pickup_requests_monthly_period_once_idx
  on public.pickup_requests (monthly_subscription_period_id)
  where monthly_subscription_period_id is not null;

-- The amount paid for a Monthly plan belongs to its one pickup. The old
-- function divided Monthly by roughly four because it assumed weekly
-- collections. Resolve the plan from the immutable paid period rather than a
-- customer-editable plan label.
create or replace function public.subscription_pickup_value(p_customer_id uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select round(
    coalesce(
      nullif(active_period.amount, 0),
      nullif(c.subscription_fee, 0),
      (plan.prices ->> coalesce(
        (select b.size
           from public.bins b
          where b.customer_id = c.id
          order by b.registered_at
          limit 1),
        '240L'
      ))::numeric,
      0
    )
    / case
        when lower(regexp_replace(coalesce(plan.frequency, ''), '[^a-zA-Z]', '', 'g')) = 'monthly'
          then 1
        else greatest(1, round(
          extract(epoch from public.plan_period(plan.frequency)) / 604800.0
          * greatest(1, (
              select count(distinct lower(btrim(d)))
                from public.bins b, unnest(coalesce(b.pickup_days, '{}')) d
               where b.customer_id = c.id
                 and coalesce(b.status, 'active') = 'active'
            ))
        ))
      end,
    2
  )
    from public.customers c
    left join lateral (
      select sp.plan_name, sp.amount
        from public.subscription_periods sp
       where sp.customer_id = c.id
         and sp.starts_at <= now()
         and sp.ends_at > now()
       order by sp.starts_at desc
       limit 1
    ) active_period on true
    left join public.pricing_plans plan
      on lower(plan.name) = lower(coalesce(active_period.plan_name, c.subscription_plan_name))
   where c.id = p_customer_id;
$$;

revoke execute on function public.subscription_pickup_value(uuid) from public, anon, authenticated;

-- Monthly subscribers choose their one date in Request Pickup. Other paid
-- plans retain the existing automatic schedule. The active verified period is
-- used instead of customers.subscription_plan_name so changing a display label
-- cannot change entitlement behavior.
create or replace function public.generate_scheduled_pickups(p_days_ahead int default 3)
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_created int;
begin
  -- Withdraw open scheduled pickups that lost paid cover, no longer match the
  -- bin schedule, or belong to a Monthly plan (which is manual and one-time).
  update public.pickup_requests pr
     set status = 'cancelled',
         completion_notes = 'Withdrawn: no longer covered by the customer''s subscription or schedule.'
    from public.customers c
    left join lateral (
      select sp.id, sp.plan_name, sp.ends_at
        from public.subscription_periods sp
       where sp.customer_id = c.id
         and sp.starts_at <= now()
         and sp.ends_at > now()
       order by sp.starts_at desc
       limit 1
    ) active_period on true
    left join public.pricing_plans plan
      on lower(plan.name) = lower(active_period.plan_name)
   where pr.customer_id = c.id
     and pr.source = 'scheduled'
     and pr.status in ('pending', 'accepted')
     and pr.slot_starts_at > now()
     and (
       active_period.id is null
       or lower(regexp_replace(coalesce(plan.frequency, ''), '[^a-zA-Z]', '', 'g')) = 'monthly'
       or pr.slot_starts_at >= active_period.ends_at
       or not exists (
         select 1
           from public.bins b, unnest(coalesce(b.pickup_days, '{}')) d
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
    select
      b.customer_id,
      d.day,
      b.pickup_time_slot as time_slot,
      active_period.plan_name as plan_name,
      active_period.ends_at as period_ends_at,
      array_agg(distinct b.type order by b.type) as bin_types,
      (array_agg(b.gps_location order by b.registered_at))[1] as bin_gps
      from public.bins b
      join public.customers c on c.id = b.customer_id
      join lateral (
        select sp.plan_name, sp.ends_at
          from public.subscription_periods sp
         where sp.customer_id = c.id
           and sp.starts_at <= now()
           and sp.ends_at > now()
         order by sp.starts_at desc
         limit 1
      ) active_period on true
      join public.pricing_plans plan
        on lower(plan.name) = lower(active_period.plan_name)
      cross join days d
     where coalesce(b.status, 'active') = 'active'
       and lower(regexp_replace(coalesce(plan.frequency, ''), '[^a-zA-Z]', '', 'g')) <> 'monthly'
       and exists (
         select 1
           from unnest(coalesce(b.pickup_days, '{}')) pd
          where lower(btrim(pd)) = lower(trim(to_char(d.day, 'FMDay')))
       )
     group by b.customer_id, d.day, b.pickup_time_slot, active_period.plan_name, active_period.ends_at
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
      'Scheduled pickup — ' || w.plan_name,
      'pending', 'paid', 'Covered by ' || w.plan_name, 0, 0,
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
      and public.slot_start(w.day, w.time_slot) < w.period_ends_at
    on conflict (customer_id, scheduled_for, time_slot) where source = 'scheduled' do nothing
    returning customer_id
  )
  select count(*) into v_created from inserted;

  -- Keep the customer's next-pickup card pointing at the soonest automatic
  -- pickup. Monthly manual pickups are set by schedule_pickup itself.
  update public.customers c
     set next_pickup_date = n.slot_starts_at,
         next_pickup_time_slot = n.time_slot,
         next_pickup_bin_types = n.bin_types
    from (
      select distinct on (customer_id) customer_id, slot_starts_at, time_slot, bin_types
        from public.pickup_requests
       where source = 'scheduled'
         and status in ('pending', 'accepted')
         and slot_starts_at > now()
       order by customer_id, slot_starts_at
    ) n
   where c.id = n.customer_id
     and (c.next_pickup_date is null or c.next_pickup_date < now() or c.next_pickup_date > n.slot_starts_at);

  return v_created;
end;
$$;

revoke execute on function public.generate_scheduled_pickups(int) from public, anon, authenticated;

-- schedule_pickup is the only customer write path for pickup_requests. It
-- locks the customer row to serialize concurrent requests, resolves the plan
-- from the verified active subscription period, and assigns a Monthly request
-- to that period. The unique index above is a second, durable backstop.
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
  p_location_lng double precision default null,
  p_payment_reference text default null
)
returns public.pickup_requests
language plpgsql security definer set search_path = public as $$
declare
  v_customer_id uuid := auth.uid();
  v_customer_name text;
  v_customer_email text;
  v_house_photo_url text;
  v_is_payg boolean;
  v_credit public.payg_pickup_credits;
  v_active_period public.subscription_periods;
  v_plan_frequency text;
  v_monthly_subscription_period_id uuid;
  v_slot_starts_at timestamptz;
  v_amount numeric := 0;
  v_original numeric := 0;
  v_discount numeric := coalesce(p_discount_applied_percentage, 0);
  v_surcharge numeric := coalesce(p_surcharge_applied_percentage, 0);
  v_method text := p_payment_method;
  v_reference text;
  v_service_value numeric;
  v_request public.pickup_requests;
  v_lat double precision := p_location_lat;
  v_lng double precision := p_location_lng;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to schedule a pickup.';
  end if;

  select full_name, email into v_customer_name, v_customer_email
    from public.profiles where id = v_customer_id;

  -- This row lock makes two calls from the same customer run one after the
  -- other, so the second one sees the Monthly period already consumed.
  select c.house_photo_url, c.subscription_is_payg
    into v_house_photo_url, v_is_payg
    from public.customers c
   where c.id = v_customer_id
   for update;

  if not found then
    raise exception 'Must be signed in as a customer to schedule a pickup.';
  end if;

  if coalesce(v_is_payg, true) then
    -- Prefer the credit the app just paid for, otherwise the oldest one.
    -- SKIP LOCKED so two simultaneous requests cannot spend the same credit.
    select * into v_credit
      from public.payg_pickup_credits
     where customer_id = v_customer_id
       and consumed_at is null
     order by (payment_reference = p_payment_reference) desc nulls last, paid_at
     limit 1
     for update skip locked;

    if not found then
      raise exception
        'Pay for this pickup first: open Choose Your Plan, select Pay As You Go and complete payment, then request your pickup.'
        using errcode = 'check_violation';
    end if;

    v_amount := v_credit.amount;
    v_original := coalesce(nullif(v_credit.original_amount, 0), v_credit.amount);
    v_discount := v_credit.discount_applied_percentage;
    v_surcharge := v_credit.surcharge_applied_percentage;
    v_method := coalesce(v_credit.payment_method, 'Paystack');
    v_reference := v_credit.payment_reference;
    v_service_value := v_credit.amount;
  else
    -- The active verified payment determines the entitlement, not the mutable
    -- customers.subscription_plan_name display field.
    select * into v_active_period
      from public.subscription_periods sp
     where sp.customer_id = v_customer_id
       and sp.starts_at <= now()
       and sp.ends_at > now()
     order by sp.starts_at desc
     limit 1;

    if not found then
      raise exception 'Your subscription does not have an active paid period. Choose a plan and complete payment first.'
        using errcode = 'check_violation';
    end if;

    select plan.frequency into v_plan_frequency
      from public.pricing_plans plan
     where lower(plan.name) = lower(v_active_period.plan_name)
     limit 1;

    if not found then
      raise exception 'Your paid subscription plan could not be found. Please contact support.'
        using errcode = 'check_violation';
    end if;

    if lower(regexp_replace(coalesce(v_plan_frequency, ''), '[^a-zA-Z]', '', 'g')) = 'monthly' then
      v_slot_starts_at := public.slot_start(
        (p_date at time zone 'Africa/Accra')::date,
        p_time_slot
      );

      if v_slot_starts_at < v_active_period.starts_at
         or v_slot_starts_at >= v_active_period.ends_at then
        raise exception 'Choose a pickup date within your active monthly subscription period.'
          using errcode = 'check_violation';
      end if;

      if exists (
        select 1
          from public.pickup_requests pr
         where pr.monthly_subscription_period_id = v_active_period.id
      ) then
        raise exception 'Your monthly subscription already has its one pickup request. Renew your plan to request another pickup.'
          using errcode = 'check_violation';
      end if;

      v_monthly_subscription_period_id := v_active_period.id;
    end if;

    v_method := 'Covered by ' || v_active_period.plan_name;
    v_service_value := public.subscription_pickup_value(v_customer_id);
  end if;

  if v_lat is null and p_location ~ '-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+' then
    v_lat := (substring(p_location from '(-?\d{1,3}\.\d+)\s*,\s*-?\d{1,3}\.\d+)'))::double precision;
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
    discount_applied_percentage, surcharge_applied_percentage, payment_method, payment_reference, paid_at,
    service_value, monthly_subscription_period_id
  )
  values (
    v_customer_id, v_customer_name, v_customer_email, p_bin_types, p_date, p_time_slot, p_location,
    v_lat, v_lng, v_house_photo_url,
    p_instructions, 'pending', 'paid', v_amount, v_original,
    v_discount, v_surcharge, v_method, v_reference,
    case when v_credit.id is not null then v_credit.paid_at else now() end,
    v_service_value, v_monthly_subscription_period_id
  )
  returning * into v_request;

  if v_credit.id is not null then
    update public.payg_pickup_credits
       set consumed_at = now(),
           pickup_request_id = v_request.id
     where id = v_credit.id;
  end if;

  insert into public.service_history (customer_id, title, type, status, amount_paid, payment_method, receipt_number, payment_reference, pickup_request_id)
  values (
    v_customer_id,
    case when v_discount > 0
      then 'Pickup Payment (' || v_discount::int || '% Delay Bonus Applied)'
      else 'Pickup Request Payment' end,
    'payment', 'completed', v_amount, v_method, p_receipt_number, v_reference, v_request.id
  );

  update public.customers
     set active_requests_count = active_requests_count + 1,
         last_pickup_request_date = now(),
         next_pickup_date = p_date,
         next_pickup_time_slot = p_time_slot,
         next_pickup_bin_types = p_bin_types,
         payment_method = v_method,
         last_payment_reference = coalesce(v_reference, last_payment_reference),
         delay_bonus_redeemed_at = case when v_discount > 0 then now() else delay_bonus_redeemed_at end
   where id = v_customer_id;

  insert into public.admin_notifications (title, message, type, customer_id, customer_name, request_id)
  values (
    'Pickup Requested',
    v_customer_name ||
      case when v_credit.id is not null
        then ' paid GHS ' || to_char(v_amount, 'FM999999990.00') ||
          case when v_discount > 0 then ' (with ' || v_discount::int || '% Delay Bonus)' else '' end
        else ' (' || v_method || ')' end ||
      ' and requested pickup for ' || array_to_string(p_bin_types, ', ') || ' (' || p_time_slot || ' at ' || p_location || ').',
    'pickup_requested', v_customer_id, v_customer_name, v_request.id
  );

  return v_request;
end;
$$;

update public.pricing_plans
   set description = 'One pickup each paid month, on the date you choose'
 where slug = 'monthly';
