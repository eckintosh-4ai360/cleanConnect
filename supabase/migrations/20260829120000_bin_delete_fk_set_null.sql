-- Deleting a bin from the admin panel failed with
--   update or delete on table "bins" violates foreign key constraint
--   "collection_events_bin_id_fkey" on table "collection_events"
-- because both FKs pointing at bins were created with the default RESTRICT.
--
-- Neither referencing row is a business record that should block (or be
-- destroyed by) removing the bin:
--
--   * collection_events is the append-only pickup history. It already
--     snapshots bin_type/address/customer_name, so the event stays readable
--     without the bin row -- and cascading would silently delete a rider's
--     completed-pickup history along with the bin.
--   * bin_requests.assigned_bin_id records which bin fulfilled a request; the
--     assigned_serial_number column beside it preserves the human-readable
--     link, and the request itself must survive the bin being retired.
--
-- SET NULL on both, matching admin_notifications_fk_set_null.sql. This fixes
-- admin_delete_bin and customer_delete_bin (bin_crud_rpcs.sql) alike.

alter table public.collection_events
  drop constraint collection_events_bin_id_fkey,
  add constraint collection_events_bin_id_fkey
    foreign key (bin_id) references public.bins(id) on delete set null;

alter table public.bin_requests
  drop constraint bin_requests_assigned_bin_id_fkey,
  add constraint bin_requests_assigned_bin_id_fkey
    foreign key (assigned_bin_id) references public.bins(id) on delete set null;
