-- Saved addresses for customers.
--
-- Profile > Address Management showed two hardcoded placeholders ("123 Green
-- St" and "456 Corporate Way") held in widget state, so anything a customer
-- added vanished when they left the screen. Addresses are now real rows, each
-- with the map coordinates riders navigate to.

create table if not exists public.customer_addresses (
  id           uuid primary key default gen_random_uuid(),
  customer_id  uuid not null references public.customers(id) on delete cascade,
  label        text not null check (length(btrim(label)) between 1 and 40),
  address      text not null check (length(btrim(address)) > 0),
  latitude     double precision check (latitude between -90 and 90),
  longitude    double precision check (longitude between -180 and 180),
  is_default   boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists customer_addresses_customer_idx
  on public.customer_addresses (customer_id, created_at);

-- At most one default per customer.
create unique index if not exists customer_addresses_one_default_idx
  on public.customer_addresses (customer_id)
  where is_default;

drop trigger if exists trg_customer_addresses_updated_at on public.customer_addresses;
create trigger trg_customer_addresses_updated_at
  before update on public.customer_addresses
  for each row execute function public.set_updated_at();

alter table public.customer_addresses enable row level security;

drop policy if exists customer_addresses_own on public.customer_addresses;
create policy customer_addresses_own on public.customer_addresses
  for all using (customer_id = auth.uid()) with check (customer_id = auth.uid());

drop policy if exists customer_addresses_all_admin on public.customer_addresses;
create policy customer_addresses_all_admin on public.customer_addresses
  for all using (public.is_admin()) with check (public.is_admin());

alter publication supabase_realtime add table public.customer_addresses;

-- ── Registration address becomes the default "Home" ─────────────────────────
-- profiles.gps_location is stored as "lat, lng" text by the register screen.
create or replace function public.seed_home_address(p_customer_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_address text;
  v_gps text;
  v_lat double precision;
  v_lng double precision;
begin
  select btrim(address), gps_location into v_address, v_gps
    from public.profiles where id = p_customer_id;

  if coalesce(v_address, '') = ''
     or exists (select 1 from public.customer_addresses where customer_id = p_customer_id) then
    return;
  end if;

  if v_gps ~ '^\s*-?\d{1,3}(\.\d+)?\s*,\s*-?\d{1,3}(\.\d+)?\s*$' then
    v_lat := split_part(v_gps, ',', 1)::double precision;
    v_lng := split_part(v_gps, ',', 2)::double precision;
    if abs(v_lat) > 90 or abs(v_lng) > 180 then
      v_lat := null;
      v_lng := null;
    end if;
  end if;

  insert into public.customer_addresses (customer_id, label, address, latitude, longitude, is_default)
  values (p_customer_id, 'Home', v_address, v_lat, v_lng, true);
end;
$$;

revoke execute on function public.seed_home_address(uuid) from public, anon, authenticated;

-- New signups: the customers row is created after the profile is filled in.
create or replace function public.trg_seed_home_address()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.seed_home_address(new.id);
  return new;
end;
$$;

drop trigger if exists trg_customers_seed_home_address on public.customers;
create trigger trg_customers_seed_home_address
  after insert on public.customers
  for each row execute function public.trg_seed_home_address();

-- Existing customers.
select public.seed_home_address(c.id) from public.customers c;
