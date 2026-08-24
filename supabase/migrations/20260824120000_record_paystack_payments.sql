-- Paystack transaction references are globally unique, so a unique index lets
-- verify-paystack-transaction record a confirmed charge with an idempotent
-- upsert. The same reference can legitimately be verified more than once — the
-- quiet re-check after a dismissed checkout sheet, or a retry after a dropped
-- response — and none of those may create a duplicate invoice row.
--
-- Partial, so the admin-raised invoices that carry no reference are unaffected
-- (a plain unique index would collapse them all onto a single NULL in some
-- engines and blocks multiple NULLs under no circumstances here, but keeping it
-- partial also documents that only Paystack rows are constrained).
create unique index if not exists payments_payment_reference_key
  on public.payments (payment_reference)
  where payment_reference is not null;
