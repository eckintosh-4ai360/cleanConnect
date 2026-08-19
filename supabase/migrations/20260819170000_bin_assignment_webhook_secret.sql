-- Shared secret that trg_notify_customer_on_bin_assignment sends to the
-- notify-bin-assignment-sms Edge Function in the x-webhook-secret header
-- (see 20260819180000_bin_assignment_sms_trigger.sql). Same pattern as
-- pickup_webhook_secret in 20260819120000_pickup_webhook_secret.sql.
--
-- Generated here rather than checked in so the value never lands in git. After
-- applying, read it back and hand the same value to the Edge Function:
--
--   select decrypted_secret from vault.decrypted_secrets
--    where name = 'bin_assignment_webhook_secret';
--   supabase secrets set BIN_ASSIGNMENT_WEBHOOK_SECRET="<that value>"
--
-- Idempotent: re-running never rotates a secret that is already live, which
-- would break dispatch until the function's env var was updated to match.

do $$
begin
  if not exists (
    select 1 from vault.secrets where name = 'bin_assignment_webhook_secret'
  ) then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'bin_assignment_webhook_secret',
      'Shared secret authenticating the bin-assignment trigger to the notify-bin-assignment-sms Edge Function.'
    );
  end if;
end $$;
