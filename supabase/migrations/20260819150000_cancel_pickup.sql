-- Customers have no way to back out of a pickup they scheduled by mistake or
-- no longer need -- 'cancelled' has been a legal pickup_requests.status value
-- since the initial schema, but nothing has ever set it. This adds the RPC.
--
-- security definer, not invoker: customers deliberately have no UPDATE policy
-- on pickup_requests (only select + insert) -- same reasoning as
-- set_pickup_destination and accept_pickup/complete_pickup. Definer plus an
-- explicit ownership + status guard in the WHERE clause keeps the write
-- narrower than a blanket UPDATE policy would.
--
-- Only 'pending'/'accepted'/'assigned'/'confirmed' rows can be cancelled --
-- i.e. anything short of 'completed'. There is no refund/credit column
-- anywhere in the schema, so cancelling a request that was already paid for
-- (schedule_pickup always marks payment_status 'paid') does not attempt one;
-- the Flutter side surfaces that as a plain disclaimer before the customer
-- confirms, same as it already does for other one-way actions.
create or replace function public.cancel_pickup(p_request_id uuid)
returns public.pickup_requests
language plpgsql security definer set search_path = public as $$
declare
  v_customer_id uuid := auth.uid();
  v_row public.pickup_requests;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to cancel a pickup.';
  end if;

  update public.pickup_requests
     set status = 'cancelled',
         updated_at = now()
   where id = p_request_id
     and customer_id = v_customer_id
     and status in ('pending', 'accepted', 'assigned', 'confirmed')
  returning * into v_row;

  if not found then
    raise exception 'This pickup can no longer be cancelled.';
  end if;

  -- Mirrors complete_pickup: decrement unconditionally, but only clear the
  -- "next pickup" pointer fields if they still refer to *this* request --
  -- the customer's displayed next pickup might be a different, still-active
  -- one.
  update public.customers
     set active_requests_count = greatest(active_requests_count - 1, 0),
         next_pickup_date = case when next_pickup_date = v_row.date then null else next_pickup_date end,
         next_pickup_time_slot = case when next_pickup_date = v_row.date then null else next_pickup_time_slot end,
         next_pickup_bin_types = case when next_pickup_date = v_row.date then null else next_pickup_bin_types end
   where id = v_customer_id;

  insert into public.admin_notifications (title, message, type, customer_id, customer_name, request_id)
  values (
    'Pickup Cancelled',
    coalesce(v_row.customer_name, 'A customer') || ' cancelled their pickup scheduled for ' ||
      to_char(v_row.date, 'FMDD Mon YYYY') || ' (' || v_row.time_slot || ').',
    'pickup_cancelled', v_customer_id, v_row.customer_name, v_row.id
  );

  return v_row;
end;
$$;
