-- Free pickups for customers who never paid.
--
-- Two independent bugs let a brand-new customer book pickups for GHS 0 and
-- have them marked "Covered by Weekly Plan":
--
--   1. customers.subscription_plan_name defaulted to 'Weekly Plan' with
--      subscription_status 'active' and subscription_fee 0, so every signup was
--      born holding an active subscription nobody had paid for.
--   2. The app decided whether to charge by comparing that name against the
--      literal 'Pay-As-You-Go', but the seeded plan in pricing_plans is called
--      'Pay As You Go'. The comparison never matched, so even a customer who
--      deliberately chose pay-as-you-go skipped the Paystack step.
--
-- Both come from treating a display string as the source of truth. The fix is
-- to derive it from pricing_plans.is_payg, keep that derivation in the database
-- where the client cannot lie about it, and enforce payment in schedule_pickup
-- rather than trusting whatever p_amount_paid the app sends.

-- ── A signup owes money by default ───────────────────────────────────────────
alter table public.customers
  alter column subscription_plan_name set default 'Pay As You Go';

-- ── Derived, database-maintained "does this customer pay per pickup?" ────────
-- Defaults to true so anything unrecognised fails closed (charge) rather than
-- open (free).
alter table public.customers
  add column if not exists subscription_is_payg boolean not null default true;

comment on column public.customers.subscription_is_payg is
  'Derived from pricing_plans.is_payg by trg_customers_sync_payg -- never set this from client code. True means every pickup must be paid for at request time.';

create or replace function public.sync_subscription_is_payg()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_is_payg boolean;
begin
  select p.is_payg into v_is_payg
    from public.pricing_plans p
   where lower(p.name) = lower(new.subscription_plan_name)
   limit 1;

  -- An unrecognised plan name (renamed, deleted, or a client's own spelling)
  -- and any non-active subscription both mean "no subscription covers this".
  new.subscription_is_payg :=
    coalesce(v_is_payg, true) or new.subscription_status <> 'active';

  return new;
end;
$$;

drop trigger if exists trg_customers_sync_payg on public.customers;
create trigger trg_customers_sync_payg
  before insert or update of subscription_plan_name, subscription_status
  on public.customers
  for each row execute function public.sync_subscription_is_payg();

-- ── Backfill ────────────────────────────────────────────────────────────────
-- Move customers who never actually paid onto pay-as-you-go. "Never paid" is
-- deliberately strict -- no payment row, no recorded fee, no Paystack reference
-- -- so anyone who really did buy a plan keeps it.
update public.customers c
   set subscription_plan_name = 'Pay As You Go',
       subscription_fee = 0
 where c.subscription_fee = 0
   and c.last_payment_reference is null
   -- An unpaid invoice is not evidence of payment, so only settled rows count.
   and not exists (
     select 1 from public.payments p
      where p.customer_id = c.id and p.status = 'paid'
   );

-- Seed the flag for every existing row, including the ones the backfill left
-- alone. This targets subscription_is_payg directly, so trg_customers_sync_payg
-- (scoped to the other two columns) does not fire and undo it -- the expression
-- below is deliberately the same one the trigger applies.
update public.customers c
   set subscription_is_payg = coalesce(
         (select p.is_payg
            from public.pricing_plans p
           where lower(p.name) = lower(c.subscription_plan_name)
           limit 1),
         true
       ) or c.subscription_status <> 'active';

-- ── Enforce payment server-side ─────────────────────────────────────────────
-- schedule_pickup is security invoker and took the client's word for
-- p_amount_paid. A pay-as-you-go customer must now arrive with a real Paystack
-- reference and a positive amount, whatever the app believes.
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
language plpgsql security invoker as $$
declare
  v_customer_id uuid := auth.uid();
  v_customer_name text;
  v_customer_email text;
  v_house_photo_url text;
  v_is_payg boolean;
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

  -- No subscription covering this pickup means it has to be paid for now.
  --
  -- The reference is required but deliberately not checked against payments:
  -- verify-paystack-transaction records that row best-effort and swallows its
  -- own failures, so insisting on it could refuse a customer whose money has
  -- already moved. Reuse is blocked instead, which stops the one exploit a
  -- modified client could actually run -- paying once and replaying the same
  -- reference for every subsequent pickup.
  if coalesce(v_is_payg, true) then
    if coalesce(p_amount_paid, 0) <= 0 or coalesce(p_payment_reference, '') = '' then
      raise exception
        'This pickup must be paid for before it can be scheduled. Subscribe to a plan or complete payment to continue.'
        using errcode = 'check_violation';
    end if;

    if exists (
      select 1 from public.pickup_requests pr
       where pr.payment_reference = p_payment_reference
    ) then
      raise exception
        'That payment has already been used for another pickup.'
        using errcode = 'check_violation';
    end if;
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
    discount_applied_percentage, surcharge_applied_percentage, payment_method, payment_reference, paid_at
  )
  values (
    v_customer_id, v_customer_name, v_customer_email, p_bin_types, p_date, p_time_slot, p_location,
    v_lat, v_lng, v_house_photo_url,
    p_instructions, 'pending', 'paid', p_amount_paid,
    case when p_original_amount > 0 then p_original_amount else p_amount_paid end,
    p_discount_applied_percentage, p_surcharge_applied_percentage, p_payment_method, p_payment_reference, now()
  )
  returning * into v_request;

  insert into public.service_history (customer_id, title, type, status, amount_paid, payment_method, receipt_number, payment_reference, pickup_request_id)
  values (
    v_customer_id,
    case when p_discount_applied_percentage > 0
      then 'Pickup Payment (' || p_discount_applied_percentage::int || '% Delay Bonus Applied)'
      else 'Pickup Request Payment' end,
    'payment', 'completed', p_amount_paid, p_payment_method, p_receipt_number, p_payment_reference, v_request.id
  );

  update public.customers
     set active_requests_count = active_requests_count + 1,
         last_pickup_request_date = now(),
         next_pickup_date = p_date,
         next_pickup_time_slot = p_time_slot,
         next_pickup_bin_types = p_bin_types,
         payment_method = p_payment_method,
         last_payment_reference = coalesce(p_payment_reference, last_payment_reference),
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
