-- Extends trg_notify_customer_on_bin_assignment (20260819180000) to also
-- text customers when they self-register a personal bin, not just when
-- admin assigns a company bin. Originally personal bins were skipped on the
-- reasoning that the customer already sees the serial number in-app right
-- after registering -- but customers still want the SMS confirmation, so
-- that ownership guard is dropped here. The 'ownership' field is now passed
-- through to the Edge Function so it can pick "registered" vs "assigned"
-- wording (see notify-bin-assignment-sms/index.ts).

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
          'size', new.size,
          'ownership', new.ownership
        )
      );
    end if;
  exception when others then
    -- never let a notification-dispatch failure block the bin registration/assignment itself
    raise warning 'notify_customer_on_bin_assignment failed: %', sqlerrm;
  end;

  return new;
end;
$$;
