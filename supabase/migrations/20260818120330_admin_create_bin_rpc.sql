-- Admin panel: creating a bin for a customer (Bins.jsx) needs an atomic
-- increment of customers.registered_bins_count — same Postgrest limitation
-- as the customer-facing register_bin RPC. security invoker (not definer):
-- unlike the rider RPCs, admins already have full RLS grants on bins,
-- customers, and bin_requests (bins_all_admin etc.), so no privilege
-- escalation is needed here — the is_admin() check is just for a clean
-- error message instead of an opaque RLS denial.

create or replace function public.admin_create_bin(
  p_customer_id uuid,
  p_serial_number text,
  p_type text,
  p_size text,
  p_ownership text,
  p_gps_location text,
  p_schedule_frequency text,
  p_request_id uuid default null
)
returns public.bins
language plpgsql security invoker as $$
declare
  v_bin public.bins;
  v_qr_code_url text;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.';
  end if;

  v_qr_code_url := 'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=' || p_serial_number;

  insert into public.bins (
    customer_id, serial_number, qr_code_data, qr_code_url, type, size, ownership,
    status, fill_level_percentage, schedule_frequency, pickup_days, gps_location, assigned_from_request_id
  )
  values (
    p_customer_id, p_serial_number, p_serial_number, v_qr_code_url, p_type, p_size, p_ownership,
    'active', 0, p_schedule_frequency, array['Monday'], p_gps_location, p_request_id
  )
  returning * into v_bin;

  update public.customers
     set registered_bins_count = registered_bins_count + 1
   where id = p_customer_id;

  if p_request_id is not null then
    update public.bin_requests
       set status = 'assigned',
           assigned_bin_id = v_bin.id,
           assigned_serial_number = p_serial_number,
           qr_code_url = v_qr_code_url,
           assigned_at = now()
     where id = p_request_id;
  end if;

  return v_bin;
end;
$$;
