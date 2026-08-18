-- Phase 6: fires the notify-riders-on-new-pickup Edge Function whenever a
-- new pending pickup request is created, replacing the Firestore
-- onDocumentCreated trigger (functions/index.js notifyRidersOnNewPickup).
--
-- security definer because vault.decrypted_secrets is only readable by
-- privileged roles, not by the customer whose INSERT fires this trigger.
-- Wrapped in exception handling so a notification-dispatch problem can never
-- roll back the customer's actual pickup request — matches the original
-- Firestore trigger's fire-and-forget nature (it always ran async, separate
-- from the client's write).

create or replace function public.notify_riders_on_new_pickup()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_secret text;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  begin
    select decrypted_secret into v_secret
      from vault.decrypted_secrets
     where name = 'pickup_webhook_secret';

    if v_secret is not null then
      perform net.http_post(
        url := 'https://mfysompctaxldphbxvkv.supabase.co/functions/v1/notify-riders-on-new-pickup',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', v_secret),
        body := jsonb_build_object(
          'requestId', new.id,
          'customerId', new.customer_id,
          'customerName', new.customer_name,
          'location', new.location,
          'timeSlot', new.time_slot,
          'binTypes', new.bin_types
        )
      );
    end if;
  exception when others then
    -- never let a notification-dispatch failure block the pickup request itself
    raise warning 'notify_riders_on_new_pickup failed: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists trg_notify_riders_on_new_pickup on public.pickup_requests;
create trigger trg_notify_riders_on_new_pickup
  after insert on public.pickup_requests
  for each row
  execute function public.notify_riders_on_new_pickup();
