-- CleanConnect: RLS policies + RPC functions.
-- See C:\Users\ECKINTOSH\.claude\plans\humble-riding-boole.md for full context.

-- ── Helper: is the current user an admin? ────────────────────────────────────
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- ── Enable RLS everywhere ─────────────────────────────────────────────────────
alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.riders enable row level security;
alter table public.bins enable row level security;
alter table public.bin_requests enable row level security;
alter table public.pickup_requests enable row level security;
alter table public.pickup_request_rejections enable row level security;
alter table public.service_history enable row level security;
alter table public.incident_reports enable row level security;
alter table public.rider_notifications enable row level security;
alter table public.routes enable row level security;
alter table public.route_stops enable row level security;
alter table public.collection_events enable row level security;
alter table public.pricing_plans enable row level security;
alter table public.admin_notifications enable row level security;
alter table public.payments enable row level security;
alter table public.vehicles enable row level security;
alter table public.garbage_sites enable row level security;
alter table public.app_settings enable row level security;

-- ── profiles ──────────────────────────────────────────────────────────────────
create policy "profiles_select_own_or_admin" on public.profiles
  for select using (id = auth.uid() or public.is_admin());
create policy "profiles_update_own_or_admin" on public.profiles
  for update using (id = auth.uid() or public.is_admin());

-- ── customers ─────────────────────────────────────────────────────────────────
create policy "customers_select_own" on public.customers
  for select using (id = auth.uid());
create policy "customers_select_assigned_rider" on public.customers
  for select using (exists (
    select 1 from public.pickup_requests pr
    where pr.customer_id = customers.id and pr.assigned_rider_id = auth.uid()
  ));
create policy "customers_select_admin" on public.customers
  for select using (public.is_admin());
create policy "customers_update_own" on public.customers
  for update using (id = auth.uid());
create policy "customers_all_admin" on public.customers
  for all using (public.is_admin()) with check (public.is_admin());

-- ── riders ────────────────────────────────────────────────────────────────────
create policy "riders_select_own" on public.riders
  for select using (id = auth.uid());
create policy "riders_select_admin" on public.riders
  for select using (public.is_admin());
create policy "riders_update_own" on public.riders
  for update using (id = auth.uid());
create policy "riders_all_admin" on public.riders
  for all using (public.is_admin()) with check (public.is_admin());

-- ── bins / bin_requests ───────────────────────────────────────────────────────
create policy "bins_all_own" on public.bins
  for all using (customer_id = auth.uid()) with check (customer_id = auth.uid());
create policy "bins_all_admin" on public.bins
  for all using (public.is_admin()) with check (public.is_admin());

create policy "bin_requests_all_own" on public.bin_requests
  for all using (customer_id = auth.uid()) with check (customer_id = auth.uid());
create policy "bin_requests_all_admin" on public.bin_requests
  for all using (public.is_admin()) with check (public.is_admin());

-- ── pickup_requests ───────────────────────────────────────────────────────────
create policy "pickup_requests_select_own_customer" on public.pickup_requests
  for select using (customer_id = auth.uid());
create policy "pickup_requests_insert_own_customer" on public.pickup_requests
  for insert with check (customer_id = auth.uid());
create policy "pickup_requests_select_rider" on public.pickup_requests
  for select using (status = 'pending' or assigned_rider_id = auth.uid());
create policy "pickup_requests_all_admin" on public.pickup_requests
  for all using (public.is_admin()) with check (public.is_admin());
-- NOTE: no generic rider UPDATE policy on purpose. Accept/complete go through the
-- security-definer RPCs below so the pending->accepted compare-and-swap can't be
-- bypassed by a raw client-side update.

create policy "pickup_request_rejections_insert_own_rider" on public.pickup_request_rejections
  for insert with check (rider_id = auth.uid());
create policy "pickup_request_rejections_select_admin" on public.pickup_request_rejections
  for select using (public.is_admin());

-- ── service_history ───────────────────────────────────────────────────────────
create policy "service_history_select_own" on public.service_history
  for select using (customer_id = auth.uid());
create policy "service_history_all_admin" on public.service_history
  for all using (public.is_admin()) with check (public.is_admin());

-- ── incident_reports ──────────────────────────────────────────────────────────
create policy "incident_reports_select_insert_own_customer" on public.incident_reports
  for select using (reporter_id = auth.uid());
create policy "incident_reports_insert_own_customer" on public.incident_reports
  for insert with check (reporter_id = auth.uid());
create policy "incident_reports_select_assigned_rider" on public.incident_reports
  for select using (assigned_rider_id = auth.uid());
create policy "incident_reports_update_assigned_rider" on public.incident_reports
  for update using (assigned_rider_id = auth.uid());
create policy "incident_reports_all_admin" on public.incident_reports
  for all using (public.is_admin()) with check (public.is_admin());

-- ── rider_notifications ───────────────────────────────────────────────────────
create policy "rider_notifications_select_own" on public.rider_notifications
  for select using (rider_id = auth.uid());
create policy "rider_notifications_update_own" on public.rider_notifications
  for update using (rider_id = auth.uid());
create policy "rider_notifications_all_admin" on public.rider_notifications
  for all using (public.is_admin()) with check (public.is_admin());
-- NOTE: no rider/customer INSERT policy on purpose — assigning a report to a
-- rider writes into *that rider's* notification feed from the admin panel /
-- assignment RPC, i.e. always a cross-actor write. It goes through
-- assign_incident_to_rider() below (security definer + is_admin() check),
-- never a raw client insert.

-- ── routes / route_stops ──────────────────────────────────────────────────────
create policy "routes_select_own_rider" on public.routes
  for select using (assigned_rider_id = auth.uid());
create policy "routes_update_own_rider" on public.routes
  for update using (assigned_rider_id = auth.uid());
create policy "routes_all_admin" on public.routes
  for all using (public.is_admin()) with check (public.is_admin());

create policy "route_stops_select_own_rider" on public.route_stops
  for select using (exists (
    select 1 from public.routes r where r.id = route_stops.route_id and r.assigned_rider_id = auth.uid()
  ));
create policy "route_stops_update_own_rider" on public.route_stops
  for update using (exists (
    select 1 from public.routes r where r.id = route_stops.route_id and r.assigned_rider_id = auth.uid()
  ));
create policy "route_stops_all_admin" on public.route_stops
  for all using (public.is_admin()) with check (public.is_admin());

-- ── collection_events ─────────────────────────────────────────────────────────
create policy "collection_events_select_own_customer" on public.collection_events
  for select using (customer_id = auth.uid());
create policy "collection_events_all_own_rider" on public.collection_events
  for all using (rider_id = auth.uid()) with check (rider_id = auth.uid());
create policy "collection_events_all_admin" on public.collection_events
  for all using (public.is_admin()) with check (public.is_admin());

-- ── pricing_plans ─────────────────────────────────────────────────────────────
create policy "pricing_plans_select_authenticated" on public.pricing_plans
  for select using (auth.role() = 'authenticated');
create policy "pricing_plans_all_admin" on public.pricing_plans
  for all using (public.is_admin()) with check (public.is_admin());

-- ── admin_notifications ───────────────────────────────────────────────────────
create policy "admin_notifications_insert_own_customer" on public.admin_notifications
  for insert with check (customer_id = auth.uid());
create policy "admin_notifications_insert_own_rider" on public.admin_notifications
  for insert with check (rider_id = auth.uid());
create policy "admin_notifications_all_admin" on public.admin_notifications
  for all using (public.is_admin()) with check (public.is_admin());

-- ── admin-only tables: payments, vehicles, garbage_sites, app_settings ────────
create policy "payments_all_admin" on public.payments
  for all using (public.is_admin()) with check (public.is_admin());
create policy "vehicles_all_admin" on public.vehicles
  for all using (public.is_admin()) with check (public.is_admin());
create policy "garbage_sites_all_admin" on public.garbage_sites
  for all using (public.is_admin()) with check (public.is_admin());
create policy "app_settings_all_admin" on public.app_settings
  for all using (public.is_admin()) with check (public.is_admin());

-- ═══════════════════════════════════════════════════════════════════════════
-- RPC functions (security-definer/invoker boundaries documented per-function)
-- ═══════════════════════════════════════════════════════════════════════════

-- ── accept_pickup: atomic pending -> accepted compare-and-swap ──────────────
create or replace function public.accept_pickup(p_request_id uuid)
returns public.pickup_requests
language plpgsql security invoker as $$
declare
  v_rider_id uuid := auth.uid();
  v_rider_name text;
  v_row public.pickup_requests;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to accept a pickup.';
  end if;

  select full_name into v_rider_name from public.profiles where id = v_rider_id;

  update public.pickup_requests
     set status = 'accepted',
         assigned_rider_id = v_rider_id,
         assigned_rider_name = v_rider_name,
         accepted_at = now()
   where id = p_request_id
     and status = 'pending'
  returning * into v_row;

  if not found then
    raise exception 'This pickup was already accepted by another rider.';
  end if;

  insert into public.admin_notifications (title, message, type, rider_id, rider_name, request_id, customer_id)
  values ('Pickup Accepted', v_rider_name || ' accepted a pickup request.',
          'pickup_accepted', v_rider_id, v_rider_name, p_request_id, v_row.customer_id);

  return v_row;
end;
$$;

-- ── complete_pickup: closes out an accepted pickup in one transaction ───────
create or replace function public.complete_pickup(
  p_request_id uuid,
  p_weight_kg numeric,
  p_notes text default null
)
returns public.pickup_requests
language plpgsql security invoker as $$
declare
  v_rider_id uuid := auth.uid();
  v_rider_name text;
  v_row public.pickup_requests;
  v_carbon_offset numeric;
begin
  if v_rider_id is null then
    raise exception 'Must be signed in as a rider to complete a pickup.';
  end if;

  update public.pickup_requests
     set status = 'completed',
         completed_at = now(),
         actual_weight_kg = p_weight_kg,
         completion_notes = p_notes
   where id = p_request_id
     and assigned_rider_id = v_rider_id
     and status = 'accepted'
  returning * into v_row;

  if not found then
    raise exception 'Pickup is not in an accepted state assigned to you.';
  end if;

  select full_name into v_rider_name from public.profiles where id = v_rider_id;
  v_carbon_offset := p_weight_kg * 0.15; -- matches existing app's offset factor

  insert into public.collection_events
    (rider_id, rider_name, customer_id, customer_name, address, bin_type,
     weight_kg, carbon_offset, status, notes, request_id)
  values
    (v_rider_id, v_rider_name, v_row.customer_id, v_row.customer_name, v_row.location,
     array_to_string(v_row.bin_types, ', '), p_weight_kg, v_carbon_offset, 'completed', p_notes, p_request_id);

  update public.riders
     set total_collections = total_collections + 1,
         total_weight_kg = total_weight_kg + p_weight_kg,
         earnings_this_month = earnings_this_month + (p_weight_kg * 0.5)
   where id = v_rider_id;

  -- only clear the customer's "next pickup" pointer if it still refers to *this* request
  update public.customers
     set last_pickup_completed_at = now(),
         next_pickup_date = null,
         next_pickup_time_slot = null,
         next_pickup_bin_types = null
   where id = v_row.customer_id
     and next_pickup_date = v_row.date;

  insert into public.admin_notifications (title, message, type, rider_id, rider_name, request_id, customer_id)
  values ('Pickup Completed', v_rider_name || ' completed a pickup (' || p_weight_kg || ' kg).',
          'pickup_completed', v_rider_id, v_rider_name, p_request_id, v_row.customer_id);

  return v_row;
end;
$$;

-- ── reject_pickup: records a rider's rejection without mutating the request ──
create or replace function public.reject_pickup(p_request_id uuid)
returns void
language plpgsql security invoker as $$
begin
  if auth.uid() is null then
    raise exception 'Must be signed in as a rider to reject a pickup.';
  end if;

  insert into public.pickup_request_rejections (request_id, rider_id)
  values (p_request_id, auth.uid())
  on conflict do nothing;
end;
$$;

-- ── mark_all_notifications_read: bulk update, replaces the WriteBatch loop ───
create or replace function public.mark_all_rider_notifications_read()
returns void
language sql security invoker as $$
  update public.rider_notifications
     set is_read = true
   where rider_id = auth.uid()
     and is_read = false;
$$;

-- ── assign_incident_to_rider: the one legitimate cross-actor notification write ─
create or replace function public.assign_incident_to_rider(p_report_id uuid, p_rider_id uuid)
returns public.incident_reports
language plpgsql security definer set search_path = public as $$
declare
  v_rider_name text;
  v_row public.incident_reports;
begin
  if not public.is_admin() then
    raise exception 'Only admins can assign incident reports.';
  end if;

  select full_name into v_rider_name from public.profiles where id = p_rider_id;

  update public.incident_reports
     set status = 'assigned', assigned_rider_id = p_rider_id, assigned_rider_name = v_rider_name
   where id = p_report_id
  returning * into v_row;

  insert into public.rider_notifications (rider_id, title, message, type, report_id)
  values (p_rider_id, 'New Report Assigned', v_row.description, 'incident_assigned', p_report_id);

  return v_row;
end;
$$;
