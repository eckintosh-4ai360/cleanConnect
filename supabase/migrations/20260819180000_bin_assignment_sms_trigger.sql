-- Fires the notify-bin-assignment-sms Edge Function whenever a company-owned
-- bin is assigned/created for a customer (admin_create_bin inserts into
-- public.bins with ownership = 'company', whether creating a bin fresh or
-- fulfilling a pending bin_requests row) -- see admin_create_bin in
-- 20260818120330_admin_create_bin_rpc.sql. Not fired for self-registered
-- personal bins (ownership = 'personal'), since the customer already sees
-- that serial number immediately in-app on registration.
--
-- security definer because vault.decrypted_secrets is only readable by
-- privileged roles. Wrapped in exception handling so a notification-dispatch
-- problem can never roll back the bin assignment itself -- same reasoning as
-- notify_riders_on_new_pickup.

create or replace function public.notify_customer_on_bin_assignment()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_secret text;
  v_phone text;
  v_customer_name text;
begin
  if new.ownership <> 'company' then
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
     where name = 'bin_assignment_webhook_secret';

    if v_secret is not null then
      perform net.http_post(
        url := 'https://mfysompctaxldphbxvkv.supabase.co/functions/v1/notify-bin-assignment-sms',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', v_secret),
        body := jsonb_build_object(
          'binId', new.id,
          'customerId', new.customer_id,
          'customerName', v_customer_name,
          'phoneNumber', v_phone,
          'serialNumber', new.serial_number,
          'type', new.type,
          'size', new.size
        )
      );
    end if;
  exception when others then
    -- never let a notification-dispatch failure block the bin assignment itself
    raise warning 'notify_customer_on_bin_assignment failed: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists trg_notify_customer_on_bin_assignment on public.bins;
create trigger trg_notify_customer_on_bin_assignment
  after insert on public.bins
  for each row
  execute function public.notify_customer_on_bin_assignment();
