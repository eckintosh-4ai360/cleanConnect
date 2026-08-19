-- Creates the shared secret that trg_notify_riders_on_new_pickup sends to the
-- notify-riders-on-new-pickup Edge Function in the x-webhook-secret header
-- (see 20260818113212_notify_riders_trigger.sql, which reads it from
-- vault.decrypted_secrets and silently skips dispatch when it is missing).
--
-- Generated here rather than checked in so the value never lands in git. After
-- applying, read it back and hand the same value to the Edge Function:
--
--   select decrypted_secret from vault.decrypted_secrets
--    where name = 'pickup_webhook_secret';
--   supabase secrets set PICKUP_WEBHOOK_SECRET="<that value>"
--
-- Idempotent: re-running never rotates a secret that is already live, which
-- would break dispatch until the function's env var was updated to match.

do $$
begin
  if not exists (
    select 1 from vault.secrets where name = 'pickup_webhook_secret'
  ) then
    perform vault.create_secret(
      encode(gen_random_bytes(32), 'hex'),
      'pickup_webhook_secret',
      'Shared secret authenticating the pickup-request trigger to the notify-riders Edge Function.'
    );
  end if;
end $$;
