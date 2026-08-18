-- admin_notifications is an append-only audit/notification log, not a business
-- record — it shouldn't block deleting the customer/rider it references (found
-- while verifying the auth migration: deleting a just-created test user failed
-- with a foreign-key violation because the default FK behavior is RESTRICT).
-- The notification's snapshotted customer_name/rider_name text already
-- preserves the human-readable context, so SET NULL is safe here.

alter table public.admin_notifications
  drop constraint admin_notifications_customer_id_fkey,
  add constraint admin_notifications_customer_id_fkey
    foreign key (customer_id) references public.customers(id) on delete set null;

alter table public.admin_notifications
  drop constraint admin_notifications_rider_id_fkey,
  add constraint admin_notifications_rider_id_fkey
    foreign key (rider_id) references public.riders(id) on delete set null;
