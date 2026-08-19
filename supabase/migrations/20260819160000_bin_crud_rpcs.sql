-- Adds delete for admin (Bins.jsx currently only supports "Manage"/edit, no
-- delete), and edit + delete for customers on their own self-registered
-- ("personal") bins. Company-assigned bins stay admin-managed only -- a
-- customer's `ownership = 'personal'` guard below blocks them from touching
-- a bin admin assigned/created, even though bins_all_own's RLS policy would
-- otherwise permit it (that policy is deliberately broad; these RPCs narrow
-- it for this specific action).

create or replace function public.customer_update_bin(
  p_bin_id uuid,
  p_frequency text,
  p_pickup_days text[]
)
returns public.bins
language plpgsql security invoker as $$
declare
  v_customer_id uuid := auth.uid();
  v_bin public.bins;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to update a bin.';
  end if;

  update public.bins
     set schedule_frequency = p_frequency,
         pickup_days = p_pickup_days
   where id = p_bin_id
     and customer_id = v_customer_id
     and ownership = 'personal'
  returning * into v_bin;

  if not found then
    raise exception 'Bin not found or is not editable.';
  end if;

  return v_bin;
end;
$$;

create or replace function public.customer_delete_bin(p_bin_id uuid)
returns void
language plpgsql security invoker as $$
declare
  v_customer_id uuid := auth.uid();
  v_deleted public.bins;
begin
  if v_customer_id is null then
    raise exception 'Must be signed in as a customer to delete a bin.';
  end if;

  delete from public.bins
   where id = p_bin_id
     and customer_id = v_customer_id
     and ownership = 'personal'
  returning * into v_deleted;

  if not found then
    raise exception 'Bin not found or cannot be deleted.';
  end if;

  update public.customers
     set registered_bins_count = greatest(registered_bins_count - 1, 0)
   where id = v_customer_id;
end;
$$;

-- security invoker (not definer): admins already have full RLS grants on
-- bins/customers (bins_all_admin etc.), matching admin_create_bin's reasoning
-- -- the is_admin() check is just for a clean error message.
create or replace function public.admin_delete_bin(p_bin_id uuid)
returns void
language plpgsql security invoker as $$
declare
  v_deleted public.bins;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.';
  end if;

  delete from public.bins
   where id = p_bin_id
  returning * into v_deleted;

  if not found then
    raise exception 'Bin not found.';
  end if;

  update public.customers
     set registered_bins_count = greatest(registered_bins_count - 1, 0)
   where id = v_deleted.customer_id;
end;
$$;
