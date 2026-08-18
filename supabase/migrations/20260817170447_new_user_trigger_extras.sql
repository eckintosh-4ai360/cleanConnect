-- Extend handle_new_user() to capture address/gps_location from signup
-- metadata and fire the same admin_notifications rows the old Dart
-- registration code wrote explicitly (customer_registered / rider_registered).

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_role text := coalesce(new.raw_user_meta_data ->> 'role', 'customer');
  v_full_name text := coalesce(new.raw_user_meta_data ->> 'full_name', 'New User');
begin
  insert into public.profiles (id, full_name, email, phone_number, address, gps_location, role)
  values (
    new.id,
    v_full_name,
    new.email,
    new.raw_user_meta_data ->> 'phone_number',
    new.raw_user_meta_data ->> 'address',
    new.raw_user_meta_data ->> 'gps_location',
    v_role
  );

  if v_role = 'customer' then
    insert into public.customers (id) values (new.id);

    insert into public.admin_notifications (title, message, type, customer_id, customer_name)
    values ('New Customer Registered', v_full_name || ' (' || new.email || ') created a new account.',
            'customer_registered', new.id, v_full_name);
  elsif v_role = 'rider' then
    insert into public.riders (id) values (new.id);

    insert into public.admin_notifications (title, message, type, rider_id, rider_name)
    values ('New Rider Registered', v_full_name || ' (' || new.email || ') registered as a rider.',
            'rider_registered', new.id, v_full_name);
  end if;

  return new;
end;
$$;
