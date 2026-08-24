-- ═══════════════════════════════════════════════════════════════════════════
-- Waste workers: the ground crew that clears reported dumps and choked
-- gutters. They are deliberately NOT riders and NOT auth users — riders drive
-- the pickup fleet and log into the mobile app, whereas a waste worker is a
-- roster entry the admin types in and dispatches by phone. Assigning a waste
-- report to a rider was always the wrong actor; this migration gives the
-- reports their own workforce table and assignment RPC.
-- ═══════════════════════════════════════════════════════════════════════════

create table public.waste_workers (
  id         uuid primary key default gen_random_uuid(),
  full_name  text not null,
  phone      text,
  zone       text,
  specialty  text not null default 'both' check (specialty in ('waste','gutter','both')),
  status     text not null default 'active' check (status in ('active','inactive')),
  notes      text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index waste_workers_status_idx on public.waste_workers (status);

create trigger trg_waste_workers_updated_at
  before update on public.waste_workers
  for each row execute function public.set_updated_at();

alter table public.waste_workers enable row level security;

-- Admin-only roster, same shape as garbage_sites / vehicles: nothing in the
-- mobile app reads or writes it.
create policy "waste_workers_all_admin" on public.waste_workers
  for all using (public.is_admin()) with check (public.is_admin());

alter publication supabase_realtime add table public.waste_workers;

-- ── incident_reports now points at a worker, not a rider ────────────────────
alter table public.incident_reports
  add column assigned_worker_id   uuid references public.waste_workers(id) on delete set null,
  add column assigned_worker_name text;

create index incident_reports_assigned_worker_id_idx
  on public.incident_reports (assigned_worker_id);

-- The admin panel has always offered an "In Progress" state, but the original
-- check constraint never allowed it — so a report could be assigned and then
-- never moved forward. With riders out of the loop the admin drives the whole
-- lifecycle, so the state has to actually exist.
alter table public.incident_reports drop constraint incident_reports_status_check;
alter table public.incident_reports add constraint incident_reports_status_check
  check (status in ('pending','assigned','in_progress','resolved','dismissed'));

-- ── assign_incident_to_worker ───────────────────────────────────────────────
-- Security definer + is_admin() guard, mirroring assign_incident_to_rider.
-- No rider_notifications insert: a waste worker has no app inbox, the admin
-- calls them. Any stale rider assignment on the row is cleared so a report
-- only ever has one owner.
create or replace function public.assign_incident_to_worker(
  p_report_id uuid,
  p_worker_id uuid
)
returns public.incident_reports
language plpgsql security definer set search_path = public as $$
declare
  v_worker public.waste_workers;
  v_row    public.incident_reports;
begin
  if not public.is_admin() then
    raise exception 'Only admins can assign incident reports.';
  end if;

  select * into v_worker from public.waste_workers where id = p_worker_id;
  if not found then
    raise exception 'That waste worker no longer exists.';
  end if;
  if v_worker.status <> 'active' then
    raise exception '% is not an active worker.', v_worker.full_name;
  end if;

  update public.incident_reports
     set status               = 'assigned',
         assigned_worker_id   = v_worker.id,
         assigned_worker_name = v_worker.full_name,
         assigned_rider_id    = null,
         assigned_rider_name  = null
   where id = p_report_id
  returning * into v_row;

  if not found then
    raise exception 'That report no longer exists.';
  end if;

  return v_row;
end;
$$;
