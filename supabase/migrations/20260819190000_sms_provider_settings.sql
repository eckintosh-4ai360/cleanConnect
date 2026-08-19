-- Lets admins configure the mNotify API key and sender ID from the admin
-- panel (Settings.jsx) instead of only via `supabase secrets set` on the
-- notify-bin-assignment-sms Edge Function. app_settings is a good home for
-- this: it's the existing admin-only singleton config row (RLS policy
-- "app_settings_all_admin", see 20260817161553_rls_and_functions.sql --
-- no select policy exists for customers/riders, so these columns are never
-- exposed to non-admin clients).
--
-- The Edge Function (see 20260819200000-ish deploy) reads these columns via
-- its service-role client and falls back to the MNOTIFY_API_KEY /
-- MNOTIFY_SENDER_ID secrets when the row hasn't been configured yet, so
-- existing deployments keep working until an admin sets these in the panel.

alter table public.app_settings
  add column if not exists mnotify_api_key text,
  add column if not exists mnotify_sender_id text;
