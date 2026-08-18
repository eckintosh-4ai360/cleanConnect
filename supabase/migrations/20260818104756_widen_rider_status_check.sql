-- riders.status was constrained to the admin panel's vocabulary
-- ('active'|'disabled'|'offline') from Phase 1, but the mobile rider app
-- uses a different vocabulary ('active'|'offline'|'on_route'|
-- 'pending_approval' — see RiderEntity's status doc comment). Firestore
-- tolerated this silently since it has no schema; Postgres's CHECK caught it
-- immediately when a real rider tried to go on_route. Widen to the union.

alter table public.riders drop constraint riders_status_check;
alter table public.riders add constraint riders_status_check
  check (status in ('active', 'disabled', 'offline', 'on_route', 'pending_approval'));
