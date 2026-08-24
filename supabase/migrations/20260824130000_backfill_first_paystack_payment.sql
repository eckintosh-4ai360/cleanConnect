-- One-off backfill for the first live Paystack charge.
--
-- Reference pd2xkbzymw (GHS 1.00, mobile money, paid 2026-08-24 16:05:37Z)
-- verified successfully, but it was taken before verify-paystack-transaction
-- learned to write public.payments, so the money moved without ever reaching
-- the admin dashboard. Every later payment is recorded by the function itself.
--
-- Idempotent twice over: the customer join yields nothing on a database that
-- has no such account (a fresh environment inserts zero rows), and
-- payments_payment_reference_key absorbs a re-run of this migration.
insert into public.payments (
  customer_id,
  customer_name,
  customer_email,
  amount,
  status,
  method,
  billing_cycle,
  description,
  payment_reference,
  invoice_date,
  paid_at
)
select
  c.id,
  p.full_name,
  p.email,
  1.00,
  'paid',
  'Paystack (mobile_money)',
  'Pay As You Go',
  'Subscription payment — Pay As You Go',
  'pd2xkbzymw',
  timestamptz '2026-08-24 16:05:37+00',
  timestamptz '2026-08-24 16:05:37+00'
from public.customers c
join public.profiles p on p.id = c.id
where c.id = 'ec9a35fe-6a9e-44d5-bbb0-1bad1265c62c'
on conflict (payment_reference) where payment_reference is not null
do nothing;
