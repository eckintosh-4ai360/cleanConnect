-- CleanConnect: initial Postgres schema for the Firebase -> Supabase migration.
-- See C:\Users\ECKINTOSH\.claude\plans\humble-riding-boole.md for full context.

create extension if not exists pgcrypto;

-- ── Identity & roles ─────────────────────────────────────────────────────────
create table public.profiles (
  id                  uuid primary key references auth.users(id) on delete cascade,
  full_name           text not null,
  email               text not null,
  phone_number        text,
  address             text,
  gps_location        text,               -- free-text string in current app, not {lat,lng}
  profile_picture_url text,
  role                text not null check (role in ('customer','rider','admin')),
  status              text not null default 'active',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create table public.customers (
  id                          uuid primary key references public.profiles(id) on delete cascade,
  contract_type               text not null default 'Residential',
  subscription_plan_id        uuid,                          -- FK added after pricing_plans
  subscription_plan_name      text not null default 'Weekly Plan',
  subscription_fee            numeric(10,2) not null default 0,
  subscription_status         text not null default 'active' check (subscription_status in ('active','inactive','suspended')),
  payment_method               text,
  outstanding_balance         numeric(10,2) not null default 0,
  next_pickup_date             timestamptz,
  next_pickup_time_slot        text,
  next_pickup_bin_types        text[],
  delay_bonus_available        boolean not null default false,
  delay_bonus_redeemed_at      timestamptz,
  last_pickup_request_date     timestamptz,
  last_pickup_completed_at     timestamptz,
  registered_bins_count        int not null default 0,
  active_requests_count        int not null default 0,
  pending_bin_requests_count   int not null default 0,
  last_invoice_id              uuid,                        -- FK added after payments
  last_invoice_date            timestamptz,
  created_at                   timestamptz not null default now(),
  updated_at                   timestamptz not null default now()
);

create table public.riders (
  id                   uuid primary key references public.profiles(id) on delete cascade,
  vehicle_type         text not null default 'Motorbike',
  license_number       text,
  national_id_number   text,
  status               text not null default 'active' check (status in ('active','disabled','offline')),
  rating               numeric(3,2) not null default 5.0,
  total_collections    int not null default 0,
  total_weight_kg      numeric(10,2) not null default 0,
  earnings_this_month  numeric(10,2) not null default 0,
  efficiency_score     numeric(5,2) not null default 100,
  current_lat          double precision,
  current_lng          double precision,
  heading              double precision,
  speed                double precision,
  last_location_update timestamptz,
  fcm_token            text,
  fcm_token_updated_at timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- ── Customer domain ──────────────────────────────────────────────────────────
create table public.bins (
  id                       uuid primary key default gen_random_uuid(),
  customer_id              uuid not null references public.customers(id) on delete cascade,
  serial_number            text not null unique,
  qr_code_data             text,
  qr_code_url              text,
  type                     text not null,
  size                     text not null,
  ownership                text not null default 'personal' check (ownership in ('personal','company')),
  status                   text not null default 'active',
  fill_level_percentage    numeric(5,2) not null default 0,
  schedule_frequency       text,
  pickup_days              text[],
  gps_location             text,
  verification_photo_url   text,
  assigned_from_request_id uuid,          -- FK added after bin_requests
  registered_at            timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);
create index bins_customer_id_idx on public.bins (customer_id);
create index bins_status_idx on public.bins (status);

create table public.bin_requests (
  id                     uuid primary key default gen_random_uuid(),
  customer_id            uuid not null references public.customers(id) on delete cascade,
  type                   text,
  size                   text,
  gps_location           text,
  notes                  text,
  status                 text not null default 'pending' check (status in ('pending','assigned','rejected')),
  assigned_bin_id        uuid references public.bins(id),
  assigned_serial_number text,
  qr_code_url            text,
  assigned_at            timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index bin_requests_customer_id_idx on public.bin_requests (customer_id);
create index bin_requests_status_idx on public.bin_requests (status);

alter table public.bins
  add constraint bins_assigned_from_request_fk
  foreign key (assigned_from_request_id) references public.bin_requests(id);

-- ── Pickup requests (mirror-collapse: root + customer subcollection -> 1 table) ─
create table public.pickup_requests (
  id                           uuid primary key default gen_random_uuid(),
  customer_id                  uuid not null references public.customers(id),
  customer_name                text not null,   -- point-in-time snapshot, intentional
  customer_email               text,
  customer_phone               text,
  bin_types                    text[] not null,
  date                         timestamptz not null,
  time_slot                    text not null,
  location                     text not null,
  instructions                 text,
  status                       text not null default 'pending'
                                 check (status in ('pending','accepted','assigned','confirmed','completed','rejected','cancelled')),
  assigned_rider_id            uuid references public.riders(id),
  assigned_rider_name          text,
  rider_lat                    double precision,
  rider_lng                    double precision,
  rider_heading                double precision,
  rider_speed                  double precision,
  rider_location_updated_at    timestamptz,
  accepted_at                  timestamptz,
  completed_at                 timestamptz,
  actual_weight_kg             numeric(10,2),
  completion_notes             text,
  payment_status               text not null default 'unpaid',
  payment_method               text,
  paid_at                      timestamptz,
  amount_paid                  numeric(10,2) not null default 0,
  original_amount               numeric(10,2) not null default 0,
  discount_applied_percentage  numeric(5,2) not null default 0,
  surcharge_applied_percentage numeric(5,2) not null default 0,
  created_at                   timestamptz not null default now(),
  updated_at                   timestamptz not null default now()
);
create index pickup_requests_customer_id_idx on public.pickup_requests (customer_id);
create index pickup_requests_assigned_rider_id_idx on public.pickup_requests (assigned_rider_id);
create index pickup_requests_pending_idx on public.pickup_requests (created_at desc) where status = 'pending';

-- replaces FieldValue.arrayUnion([riderId]) on `rejectedBy`; PK gives dedup for free
create table public.pickup_request_rejections (
  request_id  uuid not null references public.pickup_requests(id) on delete cascade,
  rider_id    uuid not null references public.riders(id) on delete cascade,
  rejected_at timestamptz not null default now(),
  primary key (request_id, rider_id)
);

create table public.service_history (
  id                       uuid primary key default gen_random_uuid(),
  customer_id              uuid not null references public.customers(id) on delete cascade,
  title                    text not null,
  type                     text not null check (type in ('payment','collection','support')),
  date                     timestamptz not null default now(),
  status                   text not null default 'completed',
  weight_kg                numeric(10,2),
  co2_offset_kg            numeric(10,2),
  composition_percentages  jsonb,
  amount_paid              numeric(10,2) not null default 0,
  receipt_number           text,
  payment_method           text,
  description              text,
  pickup_request_id        uuid references public.pickup_requests(id),
  created_at               timestamptz not null default now()
);
create index service_history_customer_id_date_idx on public.service_history (customer_id, date desc);

-- ── Incident reports (also mirror-collapsed) ─────────────────────────────────
create table public.incident_reports (
  id                  uuid primary key default gen_random_uuid(),
  reporter_id         uuid not null references public.customers(id),
  reporter_name       text not null,
  reporter_phone      text,
  description         text not null,
  media_url           text,     -- real Storage URL - the one genuine Storage usage
  media_type          text,
  location            text not null,
  status              text not null default 'pending' check (status in ('pending','assigned','resolved','dismissed')),
  assigned_rider_id   uuid references public.riders(id),
  assigned_rider_name text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index incident_reports_reporter_id_idx on public.incident_reports (reporter_id);
create index incident_reports_assigned_rider_id_idx on public.incident_reports (assigned_rider_id);

-- ── Rider notifications, routes, stops, collection events ───────────────────
create table public.rider_notifications (
  id         uuid primary key default gen_random_uuid(),
  rider_id   uuid not null references public.riders(id) on delete cascade,
  title      text not null,
  message    text not null,
  type       text not null default 'system',
  report_id  uuid references public.incident_reports(id),
  is_read    boolean not null default false,
  created_at timestamptz not null default now()
);
create index rider_notifications_rider_unread_idx on public.rider_notifications (rider_id, is_read);
create index rider_notifications_rider_created_idx on public.rider_notifications (rider_id, created_at desc);

create table public.routes (
  id                    uuid primary key default gen_random_uuid(),
  assigned_rider_id     uuid references public.riders(id),
  route_name            text not null,
  zone                  text,
  start_time            timestamptz,
  estimated_end_time    timestamptz,
  completed_at          timestamptz,
  status                text not null default 'pending' check (status in ('pending','active','completed')),
  total_distance_km     numeric(10,2) not null default 0,
  completed_distance_km numeric(10,2) not null default 0,
  total_stops           int not null default 0,
  completed_stops       int not null default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index routes_rider_active_idx on public.routes (assigned_rider_id, status);

create table public.route_stops (
  id                  uuid primary key default gen_random_uuid(),
  route_id            uuid not null references public.routes(id) on delete cascade,
  customer_name       text,
  address             text,
  bin_type            text,
  status              text not null default 'pending' check (status in ('pending','collected','problem')),
  estimated_weight_kg numeric(10,2),
  actual_weight_kg    numeric(10,2),
  notes               text,
  latitude            double precision,
  longitude           double precision,
  stop_order          int not null,
  collected_at        timestamptz,
  created_at          timestamptz not null default now()
);
create index route_stops_route_order_idx on public.route_stops (route_id, stop_order);

create table public.collection_events (
  id            uuid primary key default gen_random_uuid(),
  rider_id      uuid not null references public.riders(id),
  rider_name    text,
  customer_id   uuid references public.customers(id),
  customer_name text,
  address       text,
  bin_type      text,
  weight_kg     numeric(10,2) not null,
  carbon_offset numeric(10,2),
  qr_verified   boolean not null default false,
  qr_code_data  text,
  status        text not null default 'completed',
  photo_url     text,
  notes         text,
  route_id      uuid references public.routes(id),
  request_id    uuid references public.pickup_requests(id),
  collected_at  timestamptz not null default now()
);
create index collection_events_rider_idx on public.collection_events (rider_id, collected_at desc);
create index collection_events_customer_idx on public.collection_events (customer_id);

-- ── Pricing, notifications, admin-only tables ────────────────────────────────
create table public.pricing_plans (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique,     -- 'weekly'|'biweekly'|'monthly'|'payg' for the 4 known plans; NULL for ad-hoc plans
  name        text not null,
  frequency   text not null,
  description text,
  is_payg     boolean not null default false,
  prices      jsonb not null default '{}'::jsonb,   -- {'120L': n, '240L': n, '360L': n}
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.customers
  add constraint customers_subscription_plan_fk
  foreign key (subscription_plan_id) references public.pricing_plans(id);

create table public.admin_notifications (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  message       text not null,
  type          text not null,
  customer_id   uuid references public.customers(id),
  customer_name text,
  rider_id      uuid references public.riders(id),
  rider_name    text,
  request_id    uuid,          -- polymorphic (pickup_request/bin_request/incident_report) - no FK
  is_read       boolean not null default false,
  created_at    timestamptz not null default now()
);
create index admin_notifications_unread_idx on public.admin_notifications (is_read, created_at desc);

create table public.payments (
  id                uuid primary key default gen_random_uuid(),
  customer_id       uuid not null references public.customers(id),
  customer_name     text,
  customer_email    text,
  amount            numeric(10,2) not null,
  billing_cycle     text,
  invoice_date      timestamptz not null default now(),
  due_date          timestamptz,
  status            text not null default 'unpaid' check (status in ('paid','unpaid','pending')),
  method            text,
  description       text,
  sent_at           timestamptz,
  payment_reference text,
  paid_at           timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index payments_customer_idx on public.payments (customer_id);
create index payments_status_idx on public.payments (status);
create index payments_billing_cycle_idx on public.payments (billing_cycle);

alter table public.customers
  add constraint customers_last_invoice_fk
  foreign key (last_invoice_id) references public.payments(id);

create table public.vehicles (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  type       text,
  zone       text,
  status     text not null default 'Active' check (status in ('Active','In Service','Repair Needed')),
  load       numeric(5,2) not null default 0 check (load between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.garbage_sites (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  region         text,
  capacity       numeric(10,2),
  fill           numeric(5,2) default 0,
  status         text,
  last_collected timestamptz,
  created_at     timestamptz not null default now()
);

-- singleton config row (replaces settings/subscription_pricing doc)
create table public.app_settings (
  id           boolean primary key default true check (id),
  weekly_fee   numeric(10,2),
  biweekly_fee numeric(10,2),
  monthly_fee  numeric(10,2),
  payg_fee     numeric(10,2),
  payg_ratio   numeric(10,4),
  updated_at   timestamptz not null default now()
);

-- ── updated_at trigger, attached to every table above that has the column ───
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger trg_customers_updated_at before update on public.customers for each row execute function public.set_updated_at();
create trigger trg_riders_updated_at before update on public.riders for each row execute function public.set_updated_at();
create trigger trg_bins_updated_at before update on public.bins for each row execute function public.set_updated_at();
create trigger trg_bin_requests_updated_at before update on public.bin_requests for each row execute function public.set_updated_at();
create trigger trg_pickup_requests_updated_at before update on public.pickup_requests for each row execute function public.set_updated_at();
create trigger trg_incident_reports_updated_at before update on public.incident_reports for each row execute function public.set_updated_at();
create trigger trg_routes_updated_at before update on public.routes for each row execute function public.set_updated_at();
create trigger trg_pricing_plans_updated_at before update on public.pricing_plans for each row execute function public.set_updated_at();
create trigger trg_payments_updated_at before update on public.payments for each row execute function public.set_updated_at();
create trigger trg_vehicles_updated_at before update on public.vehicles for each row execute function public.set_updated_at();
create trigger trg_app_settings_updated_at before update on public.app_settings for each row execute function public.set_updated_at();

-- ── New-user handling: mirror auth.users -> profiles/customers/riders ───────
-- Supabase Auth stores role/full_name in raw_user_meta_data at signup time
-- (equivalent to today's app writing users/{uid} + customers/{uid}|riders/{uid}
-- in one place at registration). This trigger keeps that fan-out server-side
-- instead of relying on client code to remember all 2-3 writes.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_role text := coalesce(new.raw_user_meta_data ->> 'role', 'customer');
begin
  insert into public.profiles (id, full_name, email, phone_number, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', 'New User'),
    new.email,
    new.raw_user_meta_data ->> 'phone_number',
    v_role
  );

  if v_role = 'customer' then
    insert into public.customers (id) values (new.id);
  elsif v_role = 'rider' then
    insert into public.riders (id) values (new.id);
  end if;

  return new;
end;
$$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
