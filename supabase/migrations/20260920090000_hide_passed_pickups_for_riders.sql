-- A rider passing a pickup must only hide it from that rider. The request
-- remains pending and visible to every other rider who has not passed it.

-- The client subscribes to its own rejection rows to remove passed requests
-- from the live pickup list. Riders may see only their own rows.
create policy "pickup_request_rejections_select_own_rider"
  on public.pickup_request_rejections
  for select using (rider_id = auth.uid());

-- The composite primary key begins with request_id, while the live list looks
-- up rows by rider_id. Keep that lookup efficient as rejection history grows.
create index if not exists pickup_request_rejections_rider_id_idx
  on public.pickup_request_rejections (rider_id);

-- Realtime is needed so pressing Pass removes the card without requiring a
-- manual refresh. Existing environments may already have added this table.
do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'pickup_request_rejections'
  ) then
    alter publication supabase_realtime
      add table public.pickup_request_rejections;
  end if;
end;
$$;
