-- Paystack payments never reached the admin Payments page.
--
-- verify-paystack-transaction records each confirmed charge with
--   upsert(..., { onConflict: 'payment_reference' })
-- which PostgREST turns into `ON CONFLICT (payment_reference)`. The only unique
-- index on that column was partial (`WHERE payment_reference IS NOT NULL`), and
-- Postgres will not infer a partial index from a bare column list, so every
-- insert failed with 42P10 ("no unique or exclusion constraint matching the ON
-- CONFLICT specification"). The function logs and swallows that error by
-- design, so customers saw a successful payment while nothing was recorded.
--
-- A plain unique constraint behaves the same for admin-raised invoices (NULLs
-- are distinct, so any number of reference-less rows are still allowed) and is
-- a valid ON CONFLICT target.

drop index if exists public.payments_payment_reference_key;

alter table public.payments
  add constraint payments_payment_reference_key unique (payment_reference);

-- ── Backfill the charges lost while the upsert was failing ──────────────────
-- Every one of them is still traceable through the pickup it paid for:
-- schedule_pickup stores the Paystack reference and the amount on the request.
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
  pr.customer_id,
  pr.customer_name,
  pr.customer_email,
  pr.amount_paid,
  'paid',
  pr.payment_method,
  'Pay As You Go',
  'Pay-as-you-go pickup — ' || array_to_string(pr.bin_types, ', '),
  pr.payment_reference,
  coalesce(pr.paid_at, pr.created_at),
  coalesce(pr.paid_at, pr.created_at)
from public.pickup_requests pr
where pr.payment_reference is not null
  and pr.amount_paid > 0
  and pr.payment_method ilike 'paystack%'
on conflict (payment_reference) do nothing;
