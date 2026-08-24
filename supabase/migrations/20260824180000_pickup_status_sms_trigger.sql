-- Fires the notify-pickup-status-sms Edge Function whenever a pickup request
-- transitions into 'accepted' (rider swipes to accept, see accept_pickup in
-- 20260818101632_rider_domain_rpcs.sql) or 'completed' (rider scans the
-- customer's bin QR code, see complete_pickup in
-- 20260819210000_qr_verified_pickup_completion.sql). Matching bin approval,
-- these are the two remaining SMS touchpoints for a pickup's lifecycle.
--
-- pickup_requests.customer_phone is a point-in-time snapshot column that
-- schedule_pickup never actually populates, so -- like
-- notify_customer_on_bin_assignment -- this looks the number up live from
-- profiles instead of trusting that column.
--
-- security definer because vault.decrypted_secrets is only readable by
-- privileged roles. Wrapped in exception handling so a notification-dispatch
-- problem can never roll back the accept/complete transition itself -- same
-- reasoning as notify_riders_on_new_pickup and notify_customer_on_bin_assignment.

create or replace function public.notify_customer_on_pickup_status_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_secret text;
  v_phone text;
  v_customer_name text;
begin
  if new.status not in ('accepted', 'completed') then
    return new;
  end if;

  begin
    select phone_number, full_name into v_phone, v_customer_name
      from public.profiles where id = new.customer_id;

    if v_phone is null or v_phone = '' then
      return new;
    end if;

    select decrypted_secret into v_secret
      from vault.decrypted_secrets
     where name = 'pickup_status_sms_webhook_secret';

    if v_secret is not null then
      perform net.http_post(
        url := 'https://mfysompctaxldphbxvkv.supabase.co/functions/v1/notify-pickup-status-sms',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', v_secret),
        body := jsonb_build_object(
          'requestId', new.id,
          'customerId', new.customer_id,
          'customerName', v_customer_name,
          'phoneNumber', v_phone,
          'status', new.status,
          'riderName', new.assigned_rider_name,
          'timeSlot', new.time_slot,
          'location', new.location,
          'weightKg', new.actual_weight_kg
        )
      );
    end if;
  exception when others then
    -- never let a notification-dispatch failure block the accept/complete transition itself
    raise warning 'notify_customer_on_pickup_status_change failed: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists trg_notify_customer_on_pickup_status_change on public.pickup_requests;
create trigger trg_notify_customer_on_pickup_status_change
  after update on public.pickup_requests
  for each row
  when (old.status is distinct from new.status)
  execute function public.notify_customer_on_pickup_status_change();
