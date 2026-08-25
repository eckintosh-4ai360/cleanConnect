-- CleanConnect: add support contact fields to the singleton app_settings row.
-- Admin panel edits these; the mobile app reads them so contact details are
-- configurable from the dashboard without a code deploy.

alter table public.app_settings
  add column if not exists support_phone text,
  add column if not exists support_email text;

-- Seed with the real CleanConnect contact details
update public.app_settings
set
  support_phone = '+233 24 881 4260',
  support_email = 'support@cleanconnect.com'
where id = true;

-- Allow any authenticated user (customers, riders) to SELECT app_settings
-- so the mobile app can fetch the contact details without needing admin role.
-- Writes remain restricted to admins via the existing app_settings_all_admin policy.
create policy "app_settings_read_authenticated"
  on public.app_settings
  for select
  using (auth.role() = 'authenticated');
