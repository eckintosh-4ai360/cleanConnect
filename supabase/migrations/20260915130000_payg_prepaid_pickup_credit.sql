-- Pay-as-you-go: pay first, then request exactly one pickup.
--
-- Until now a pay-as-you-go customer "activated" the plan for free and was
-- charged inside the pickup form. The business rule is the reverse: choosing
-- pay-as-you-go takes payment immediately, that payment buys one pickup, and
-- the next pickup needs another payment.
--
-- A payment becomes a row in payg_pickup_credits. Only the service role can
-- create one (verify-paystack-transaction, after Paystack itself confirms the
-- charge), and schedule_pickup consumes one per pay-as-you-go request. The
-- customer can see their credits but never write them.
--
-- This also closes two ways around payment enforcement that existed on the
-- live database:
--   * pickup_requests_insert_own_customer let a customer insert a request row
--     directly, skipping schedule_pickup entirely;
--   * two older schedule_pickup overloads (without p_payment_reference) were
--     still callable and never checked payment at all.

-- ── Credits ────────────────────────────────────────────────────────────────
create table if not exists public.payg_pickup_credits (
  id                            uuid primary key default gen_random_uuid(),
  customer_id                   uuid not null references public.customers(id) on delete cascade,
  payment_reference             text not null unique,
  -- What the pickup is worth to the company (GHS, after Paystack's fee).
  amount                        numeric(10,2) not null check (amount > 0),
  -- What the customer was actually charged, Paystack fee included.
  amount_charged                numeric(10,2),
  original_amount               numeric(10,2),
  discount_applied_percentage   numeric(5,2) not null default 0,
  surcharge_applied_percentage  numeric(5,2) not null default 0,
  payment_method                text,
  paid_at                       timestamptz not null default now(),
  consumed_at                   timestamptz,
  pickup_request_id             uuid references public.pickup_requests(id) on delete set null,
  created_at                    timestamptz not null default now()
);

comment on table public.payg_pickup_credits is
  'One prepaid pay-as-you-go pickup per row. Created by verify-paystack-transaction (service role) after Paystack confirms the charge; consumed by schedule_pickup; released again by cancel_pickup.';

create index if not exists payg_pickup_credits_available_idx
  on public.payg_pickup_credits (customer_id, paid_at)
  where consumed_at is null;

alter table public.payg_pickup_credits enable row level security;

drop policy if exists payg_pickup_credits_select_own on public.payg_pickup_credits;
create policy payg_pickup_credits_select_own on public.payg_pickup_credits
  for select using (customer_id = auth.uid());

drop policy if exists payg_pickup_credits_all_admin on public.payg_pickup_credits;
create policy payg_pickup_credits_all_admin on public.payg_pickup_credits
  for all using (public.is_admin()) with check (public.is_admin());

alter publication supabase_realtime add table public.payg_pickup_credits;

-- ── What each pickup is worth, fixed at booking time ───────────────────────
-- Rider commission is a share of this (see rider_commission migration).
alter table public.pickup_requests
  add column if not exists service_value numeric(10,2);

comment on column public.pickup_requests.service_value is
  'GHS value of this pickup to the company, set by schedule_pickup: the prepaid amount for pay-as-you-go, or the subscription fee divided by the plan''s pickups per month.';

create or replace function public.subscription_pickup_value(p_customer_id uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select round(
    coalesce(
      nullif(c.subscription_fee, 0),
      (p.prices ->> coalesce(
        (select b.size from public.bins b
          where b.customer_id = c.id
          order by b.registered_at limit 1),
        '240L'))::numeric,
      0
    )
    / case lower(replace(replace(coalesce(p.frequency, ''), '-', ''), ' ', ''))
        when 'weekly'   then 4
        when 'biweekly' then 2
        else 1
      end,
    2)
  from public.customers c
  left join public.pricing_plans p on lower(p.name) = lower(c.subscription_plan_name)
  where c.id = p_customer_id;
$$;

-- Internal helper: it reads any customer's plan, so keep it off the API.
revoke execute on function public.subscription_pickup_value(uuid) from public, anon, authenticated;

-- ── Requests can only be created through schedule_pickup ───────────────────
drop policy if exists pickup_requests_insert_own_customer on public.pickup_requests;

drop function if exists public.schedule_pickup(
  text[], timestamptz, text, text, numeric, text, text, numeric, numeric, numeric, text);
drop function if exists public.schedule_pickup(
  text[], timestamptz, text, text, numeric, text, text, numeric, numeric, numeric, text,
  double precision, double precision);

-- Same signature as before so existing app builds keep calling it. For a
-- pay-as-you-go customer the client's amount, discount, surcharge and
-- reference are ignored: everything comes from the credit being consumed.
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

  select house_photo_url, subscription_is_payg
    into v_house_photo_url, v_is_payg
    from public.customers where id = v_customer_id;

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
    v_method := 'Covered by ' || (select subscription_plan_name from public.customers where id = v_customer_id);
    v_service_value := public.subscription_pickup_value(v_customer_id);
  end if;

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
    location_lat, location_lng, house_photo_url,
    instructions, status, payment_status, amount_paid, original_amount,
    discount_applied_percentage, surcharge_applied_percentage, payment_method, payment_reference, paid_at,
    service_value
  )
  values (
    v_customer_id, v_customer_name, v_customer_email, p_bin_types, p_date, p_time_slot, p_location,
    v_lat, v_lng, v_house_photo_url,
    p_instructions, 'pending', 'paid', v_amount, v_original,
    v_discount, v_surcharge, v_method, v_reference,
    case when v_credit.id is not null then v_credit.paid_at else now() end,
    v_service_value
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

-- ── Cancelling a prepaid pickup gives the credit back ─────────────────────
create or replace function public.cancel_pickup(p_request_id uuid)
returns public.pickup_requests
language plpgsql security definer set search_path = public as $$
declare
  v_customer_id uuid := auth.uid();
  v_row public.pickup_requests;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to cancel a pickup.';
  end if;

  update public.pickup_requests
     set status = 'cancelled',
         updated_at = now()
   where id = p_request_id
     and customer_id = v_customer_id
     and status in ('pending', 'accepted', 'assigned', 'confirmed')
  returning * into v_row;

  if not found then
    raise exception 'This pickup can no longer be cancelled.';
  end if;

  -- The customer paid for a pickup that will not happen, so they can use the
  -- same payment for their next request instead of paying twice.
  update public.payg_pickup_credits
     set consumed_at = null,
         pickup_request_id = null
   where pickup_request_id = v_row.id;

  -- Mirrors complete_pickup: decrement unconditionally, but only clear the
  -- "next pickup" pointer fields if they still refer to *this* request --
  -- the customer's displayed next pickup might be a different, still-active
  -- one.
  update public.customers
     set active_requests_count = greatest(active_requests_count - 1, 0),
         next_pickup_date = case when next_pickup_date = v_row.date then null else next_pickup_date end,
         next_pickup_time_slot = case when next_pickup_date = v_row.date then null else next_pickup_time_slot end,
         next_pickup_bin_types = case when next_pickup_date = v_row.date then null else next_pickup_bin_types end
   where id = v_customer_id;

  insert into public.admin_notifications (title, message, type, customer_id, customer_name, request_id)
  values (
    'Pickup Cancelled',
    coalesce(v_row.customer_name, 'A customer') || ' cancelled their pickup scheduled for ' ||
      to_char(v_row.date, 'FMDD Mon YYYY') || ' (' || v_row.time_slot || ').',
    'pickup_cancelled', v_customer_id, v_row.customer_name, v_row.id
  );

  return v_row;
end;
$$;

-- ── Backfill service_value on pickups not yet completed ────────────────────
update public.pickup_requests pr
   set service_value = case
         when pr.amount_paid > 0 then pr.amount_paid
         else public.subscription_pickup_value(pr.customer_id)
       end
 where pr.service_value is null
   and pr.status not in ('completed', 'cancelled');
