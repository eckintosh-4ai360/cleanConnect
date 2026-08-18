-- Phase 6: pg_net lets a Postgres trigger fire an async HTTP request (used
-- to invoke the notify-riders-on-new-pickup Edge Function on pickup_requests
-- insert, replacing the Firestore onDocumentCreated trigger).
create extension if not exists pg_net with schema extensions;
