-- Riders are paid a commission on each pickup instead of per kilogram.
--
-- complete_pickup and mark_stop_collected used to add weight_kg * 0.15 to
-- riders.earnings_this_month. A rider now earns a percentage of what the
-- pickup is worth (pickup_requests.service_value, fixed at booking); the rest
-- is the company's. The split is an admin setting, 70/30 by default, and the
-- rate in force is stored on every collection so a later change never
-- rewrites what a rider already earned.

alter table public.app_settings
  add column if not exists rider_commission_percentage numeric(5,2) not null default 70
    check (rider_commission_percentage between 0 and 100);

comment on column public.app_settings.rider_commission_percentage is
  'Share of each pickup''s service_value paid to the rider who completes it. The company keeps the remainder.';

alter table public.collection_events
  add column if not exists service_value numeric(10,2),
  add column if not exists rider_commission_percentage numeric(5,2),
  add column if not exists rider_earning numeric(10,2),
  add column if not exists company_earning numeric(10,2);

-- Riders read their own collections but no longer write them directly: every
-- insert goes through complete_pickup / mark_stop_collected, which now set the
-- earning columns. A write policy would let a rider award themselves pay.
drop policy if exists collection_events_all_own_rider on public.collection_events;
drop policy if exists collection_events_select_own_rider on public.collection_events;
create policy collection_events_select_own_rider on public.collection_events
  for select using (rider_id = auth.uid());

-- riders_update_own lets a rider update their whole row. Pay is now real
-- money, so the counters the completion RPCs maintain are off limits to direct
-- API writes. The RPCs are security definer and run as the table owner, so
-- current_user tells them apart from a request made with a user's JWT.
create or replace function public.guard_rider_earnings()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() and (
       new.earnings_this_month is distinct from old.earnings_this_month
    or new.total_collections is distinct from old.total_collections
    or new.total_weight_kg is distinct from old.total_weight_kg
  ) then
    raise exception 'Rider earnings and collection totals can only change by completing pickups.'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_riders_guard_earnings on public.riders;
create trigger trg_riders_guard_earnings
  before update on public.riders
  for each row execute function public.guard_rider_earnings();

create or replace function public.rider_commission_percentage()
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce((select rider_commission_percentage from public.app_settings where id), 70);
$$;

-- ── complete_pickup ─────────────────────────────────────────────────────────
create or replace function public.complete_pickup(
  p_request_id uuid,
  p_weight_kg numeric,
  p_qr_code_data text,
  p_notes text default null
)
returns public.pickup_requests
language plpgsql security definer set search_path = public as $$
declare
  v_rider_id uuid := auth.uid();
  v_rider_name text;
  v_row public.pickup_requests;
  v_bin public.bins;
  v_carbon_offset numeric;
  v_service_value numeric;
  v_pct numeric := public.rider_commission_percentage();
  v_rider_earning numeric;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to complete a pickup.';
  end if;

  if p_qr_code_data is null or btrim(p_qr_code_data) = '' then
    raise exception 'Scan the customer''s bin QR code before completing this pickup.';
  end if;

  select * into v_row from public.pickup_requests
   where id = p_request_id and assigned_rider_id = v_rider_id and status = 'accepted';

  if not found then
    raise exception 'Pickup is not in an accepted state assigned to you.';
  end if;

  select * into v_bin from public.bins where serial_number = btrim(p_qr_code_data);

  if not found then
    raise exception 'This QR code does not match any registered bin.';
  end if;

  if v_bin.customer_id <> v_row.customer_id then
    raise exception 'This bin belongs to a different customer -- scan %''s bin instead.', coalesce(v_row.customer_name, 'the right customer');
  end if;

  -- Re-guard on assigned_rider_id/status here too (not just the read above):
  -- this is the actual atomic state-transition, so it's what stops two
  -- concurrent completions of the same pickup from both succeeding.
  update public.pickup_requests
     set status = 'completed',
         completed_at = now(),
         actual_weight_kg = p_weight_kg,
         completion_notes = p_notes
   where id = p_request_id and assigned_rider_id = v_rider_id and status = 'accepted'
  returning * into v_row;

  if not found then
    raise exception 'Pickup is not in an accepted state assigned to you.';
  end if;

  select full_name into v_rider_name from public.profiles where id = v_rider_id;
  v_carbon_offset := round((p_weight_kg * 0.52)::numeric, 1);

  -- Requests booked before service_value existed fall back to what was paid.
  v_service_value := coalesce(
    v_row.service_value,
    nullif(v_row.amount_paid, 0),
    public.subscription_pickup_value(v_row.customer_id),
    0);
  v_rider_earning := round(v_service_value * v_pct / 100, 2);

  insert into public.collection_events
    (rider_id, rider_name, customer_id, customer_name, address, bin_type, bin_id,
     weight_kg, carbon_offset, qr_verified, qr_code_data, status, notes, request_id,
     service_value, rider_commission_percentage, rider_earning, company_earning)
  values
    (v_rider_id, v_rider_name, v_row.customer_id, v_row.customer_name, v_row.location,
     array_to_string(v_row.bin_types, ', '), v_bin.id, p_weight_kg, v_carbon_offset,
     true, p_qr_code_data, 'completed', p_notes, p_request_id,
     v_service_value, v_pct, v_rider_earning, v_service_value - v_rider_earning);

  update public.riders
     set total_collections = total_collections + 1,
         total_weight_kg = total_weight_kg + p_weight_kg,
         earnings_this_month = earnings_this_month + v_rider_earning
   where id = v_rider_id;

  update public.customers
     set last_pickup_completed_at = now(),
         next_pickup_date = null,
         next_pickup_time_slot = null,
         next_pickup_bin_types = null
   where id = v_row.customer_id
     and next_pickup_date = v_row.date;

  insert into public.admin_notifications (title, message, type, rider_id, rider_name, request_id, customer_id)
  values ('Pickup Completed', v_rider_name || ' completed the pickup for ' || coalesce(v_row.customer_name, 'a customer') || '.',
          'pickup_completed', v_rider_id, v_rider_name, p_request_id, v_row.customer_id);

  return v_row;
end;
$$;

-- ── mark_stop_collected ─────────────────────────────────────────────────────
-- Route stops are company collections with no customer payment behind them,
-- so there is nothing to take a commission of: they are logged with a zero
-- earning. Now security definer, since riders lost direct insert rights.
create or replace function public.mark_stop_collected(
  p_stop_id uuid,
  p_weight_kg numeric,
  p_notes text default null,
  p_qr_code_data text default null
)
returns public.route_stops
language plpgsql security definer set search_path = public as $$
declare
  v_rider_id uuid := auth.uid();
  v_rider_name text;
  v_stop public.route_stops;
  v_carbon_offset numeric;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to mark a stop collected.';
  end if;

  update public.route_stops
     set status = 'collected',
         actual_weight_kg = p_weight_kg,
         notes = coalesce(p_notes, notes),
         collected_at = now()
   where id = p_stop_id
     and exists (
       select 1 from public.routes r
        where r.id = route_stops.route_id and r.assigned_rider_id = v_rider_id
     )
  returning * into v_stop;

  if not found then
    raise exception 'Stop not found or not assigned to you.';
  end if;

  select full_name into v_rider_name from public.profiles where id = v_rider_id;
  v_carbon_offset := round((p_weight_kg * 0.52)::numeric, 1);

  insert into public.collection_events
    (rider_id, rider_name, customer_name, address, bin_type, weight_kg,
     carbon_offset, qr_verified, qr_code_data, status, notes, route_id,
     service_value, rider_commission_percentage, rider_earning, company_earning)
  values
    (v_rider_id, v_rider_name, v_stop.customer_name, v_stop.address, v_stop.bin_type, p_weight_kg,
     v_carbon_offset, p_qr_code_data is not null and p_qr_code_data <> '', p_qr_code_data,
     'completed', p_notes, v_stop.route_id,
     0, public.rider_commission_percentage(), 0, 0);

  update public.riders
     set total_collections = total_collections + 1,
         total_weight_kg = total_weight_kg + p_weight_kg
   where id = v_rider_id;

  return v_stop;
end;
$$;
