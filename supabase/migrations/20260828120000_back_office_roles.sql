-- Back-office roles.
--
-- The panel used to know exactly one privileged role: 'admin'. Real operations
-- teams have titles — a financial secretary who lives in Payments, supervisors,
-- general staff, support agents — so the admin panel can now create those
-- accounts itself instead of someone hand-inserting rows in Supabase.
--
-- Access model:
--   * Every back-office role signs into the admin panel and shares the same
--     database privileges. is_admin() below is widened to mean "is a panel
--     user", which is what every existing RLS policy has always used it for.
--   * Which pages a role actually sees is decided per-role in the panel
--     (admin_panel/src/roles.js) — that is UX, not a security boundary.
--   * The things only a true 'admin' may do — creating panel users, changing
--     somebody's role or status — are gated on is_super_admin() and enforced
--     here in the database, not by hiding a button.

-- ── Role vocabulary ──────────────────────────────────────────────────────────
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in (
    'customer', 'rider',
    'admin', 'financial_secretary', 'supervisor', 'staff', 'support'
  ));

-- ── Helpers ──────────────────────────────────────────────────────────────────
-- The narrow check the old is_admin() used to be. Guards user management only.
create or replace function public.is_super_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and status = 'active'
  );
$$;

-- Widened: any active back-office account. Every RLS policy in the schema calls
-- this, so widening it here is what grants the new roles panel access.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and status = 'active'
      and role in ('admin', 'financial_secretary', 'supervisor', 'staff', 'support')
  );
$$;

-- ── New-user fan-out ─────────────────────────────────────────────────────────
-- Same as before for customers/riders; back-office signups get a profile row
-- (no customers/riders row to hang off) and an admin notification of their own.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_role text := coalesce(new.raw_user_meta_data ->> 'role', 'customer');
  v_full_name text := coalesce(new.raw_user_meta_data ->> 'full_name', 'New User');
begin
  insert into public.profiles (id, full_name, email, phone_number, address, gps_location, role)
  values (
    new.id,
    v_full_name,
    new.email,
    new.raw_user_meta_data ->> 'phone_number',
    new.raw_user_meta_data ->> 'address',
    new.raw_user_meta_data ->> 'gps_location',
    v_role
  );

  if v_role = 'customer' then
    insert into public.customers (id) values (new.id);

    insert into public.admin_notifications (title, message, type, customer_id, customer_name)
    values ('New Customer Registered', v_full_name || ' (' || new.email || ') created a new account.',
            'customer_registered', new.id, v_full_name);
  elsif v_role = 'rider' then
    insert into public.riders (id) values (new.id);

    insert into public.admin_notifications (title, message, type, rider_id, rider_name)
    values ('New Rider Registered', v_full_name || ' (' || new.email || ') registered as a rider.',
            'rider_registered', new.id, v_full_name);
  else
    insert into public.admin_notifications (title, message, type)
    values ('New Panel User Created',
            v_full_name || ' (' || new.email || ') was added as ' ||
              initcap(replace(v_role, '_', ' ')) || '.',
            'staff_registered');
  end if;

  return new;
end;
$$;

-- ── Guard: who may edit a panel user ─────────────────────────────────────────
-- profiles_update_own_or_admin lets any panel user update profile rows, which
-- without this would let a support agent promote themselves to admin. Roles and
-- panel-user status are super-admin territory.
create or replace function public.guard_profile_privilege_changes()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_back_office constant text[] :=
    array['admin', 'financial_secretary', 'supervisor', 'staff', 'support'];
begin
  -- Service-role callers (edge functions, migrations, the SQL editor) have no
  -- auth.uid() and are already trusted; the guard is for panel sessions.
  if auth.uid() is null then
    return new;
  end if;

  if new.role is distinct from old.role then
    if not public.is_super_admin() then
      raise exception 'Only an admin can change a user''s role.';
    end if;
    if old.id = auth.uid() then
      raise exception 'You cannot change your own role.';
    end if;
    -- Flipping between panel and app roles would leave the customers/riders row
    -- the FK-bearing tables expect either missing or orphaned.
    if (old.role = any (v_back_office)) <> (new.role = any (v_back_office)) then
      raise exception 'A panel user''s role can only be changed to another panel role.';
    end if;
  end if;

  if (new.status is distinct from old.status) and (old.role = any (v_back_office)) then
    if not public.is_super_admin() then
      raise exception 'Only an admin can change a panel user''s status.';
    end if;
    if old.id = auth.uid() then
      raise exception 'You cannot change your own status.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_profiles_guard_privileges on public.profiles;
create trigger trg_profiles_guard_privileges
  before update on public.profiles
  for each row execute function public.guard_profile_privilege_changes();
