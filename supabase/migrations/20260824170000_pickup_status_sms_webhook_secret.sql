-- Shared secret that trg_notify_customer_on_pickup_status_change sends to the
-- notify-pickup-status-sms Edge Function in the x-webhook-secret header (see
-- 20260824160000_pickup_status_sms_trigger.sql). Same pattern as
-- bin_assignment_webhook_secret in 20260819170000_bin_assignment_webhook_secret.sql.
--
-- Generated here rather than checked in so the value never lands in git. After
-- applying, read it back and hand the same value to the Edge Function:
--
--   select decrypted_secret from vault.decrypted_secrets
--    where name = 'pickup_status_sms_webhook_secret';
--   supabase secrets set PICKUP_STATUS_SMS_WEBHOOK_SECRET="<that value>"
--
-- Idempotent: re-running never rotates a secret that is already live, which
-- would break dispatch until the function's env var was updated to match.

do $$
begin
  if not exists (
    select 1 from vault.secrets where name = 'pickup_status_sms_webhook_secret'
  ) then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'pickup_status_sms_webhook_secret',
      'Shared secret authenticating the pickup-status trigger to the notify-pickup-status-sms Edge Function.'
    );
  end if;
end $$;
