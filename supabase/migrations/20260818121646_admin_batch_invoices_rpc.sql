-- Admin panel: Payments.jsx's "Send Batch Invoices" creates one payment row
-- per un-invoiced active customer and increments each customer's
-- outstanding_balance — same Postgrest increment limitation as elsewhere,
-- now looped over potentially many customers in one function.
-- security invoker: admins already have full RLS grants on every table
-- touched here.

create or replace function public.admin_generate_batch_invoices(
  p_billing_cycle text,
  p_billing_cycle_label text
)
returns integer
language plpgsql security invoker as $$
declare
  v_customer record;
  v_amount numeric;
  v_invoice_id uuid;
  v_count integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.';
  end if;

  for v_customer in
    select c.id, c.subscription_fee, c.payment_method, p.full_name, p.email
      from public.customers c
      join public.profiles p on p.id = c.id
     where c.subscription_status <> 'suspended'
       and not exists (
         select 1 from public.payments pay
          where pay.customer_id = c.id and pay.billing_cycle = p_billing_cycle
       )
  loop
    v_amount := coalesce(nullif(v_customer.subscription_fee, 0), 50);

    insert into public.payments (
      customer_id, customer_name, customer_email, amount, billing_cycle,
      due_date, status, method, description, sent_at
    )
    values (
      v_customer.id, v_customer.full_name, v_customer.email, v_amount, p_billing_cycle,
      now() + interval '14 days', 'unpaid', coalesce(v_customer.payment_method, 'Mobile Money'),
      p_billing_cycle_label || ' waste collection service invoice', now()
    )
    returning id into v_invoice_id;

    update public.customers
       set outstanding_balance = outstanding_balance + v_amount,
           last_invoice_id = v_invoice_id,
           last_invoice_date = now()
     where id = v_customer.id;

    insert into public.service_history (customer_id, title, type, status, amount_paid, receipt_number)
    values (v_customer.id, p_billing_cycle_label || ' Service Invoice', 'payment', 'pending', v_amount, v_invoice_id::text);

    v_count := v_count + 1;
  end loop;

  if v_count > 0 then
    insert into public.admin_notifications (title, message, type)
    values ('Batch Invoices Sent', v_count || ' ' || p_billing_cycle_label || ' invoice(s) sent to customers.', 'payment');
  end if;

  return v_count;
end;
$$;
