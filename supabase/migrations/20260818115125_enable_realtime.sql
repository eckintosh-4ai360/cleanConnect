-- Every .stream() call in the Flutter app (Phases 3-5) and every
-- postgres_changes subscription in the admin panel (Phase 7) relies on
-- Supabase Realtime — which requires each table to be explicitly added to
-- the supabase_realtime publication, separate from RLS. Found while wiring
-- up the admin panel's live notification feed: the publication was empty,
-- meaning every "live" screen built so far has actually just been a
-- one-time snapshot that silently never updates. All prior REST-based
-- testing never caught this since curl doesn't exercise the WebSocket path.

alter publication supabase_realtime add table
  public.customers,
  public.riders,
  public.bins,
  public.bin_requests,
  public.pickup_requests,
  public.service_history,
  public.incident_reports,
  public.rider_notifications,
  public.routes,
  public.route_stops,
  public.collection_events,
  public.pricing_plans,
  public.admin_notifications,
  public.payments,
  public.vehicles,
  public.garbage_sites,
  public.app_settings;
