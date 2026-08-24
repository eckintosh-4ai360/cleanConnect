-- An FCM token identifies a *device*, not the account that registered it, but
-- riders.fcm_token stores it against a rider row and
-- notify-riders-on-new-pickup fans a pickup alert out to every non-null token
-- it finds there. Nothing ever cleared that column, so a rider who signed out
-- of a shared/test device left it registered forever: the next person to sign
-- in on that phone -- a customer, typically -- kept receiving rider pickup
-- alerts, which the app answers with a repeating vibration it only stops from
-- the rider-only incoming-request screen. Placing a pickup as that customer
-- therefore buzzed their own phone until the app was killed.
--
-- The client now clears its own token on sign-out, but that cannot repair rows
-- already orphaned (or a session killed mid-logout). This RPC is the repair
-- path, run by whoever signs in on the device next.
--
-- security definer, not invoker: the caller is usually a customer, and riders
-- has no UPDATE policy letting one account touch another's row -- correctly
-- so. Definer plus the two guards below keeps this far narrower than any
-- policy could: it only ever writes NULL, only to rows whose fcm_token is
-- byte-for-byte the token the caller presented, and never to the caller's own
-- row (a signed-in rider re-registering must not wipe themselves). Knowing a
-- token is not a capability worth guarding -- FCM hands it to the device that
-- owns it and to nobody else -- and the only effect is to stop sending pushes
-- to that device.
create or replace function public.release_device_fcm_token(p_token text)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_released integer;
begin
  if v_uid is null then
    raise exception 'Must be signed in to release a device push token.';
  end if;

  if p_token is null or length(p_token) = 0 then
    return 0;
  end if;

  update public.riders
     set fcm_token = null
   where fcm_token = p_token
     and id <> v_uid;

  get diagnostics v_released = row_count;
  return v_released;
end;
$$;

revoke all on function public.release_device_fcm_token(text) from public;
grant execute on function public.release_device_fcm_token(text) to authenticated;
