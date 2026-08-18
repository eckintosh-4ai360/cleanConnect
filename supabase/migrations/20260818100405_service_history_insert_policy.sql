-- Phase 1 gave service_history a SELECT policy for customers but no INSERT
-- policy, so schedule_pickup/pay_outstanding_balance/reportProblem all fail
-- when they try to log a service_history row for the calling customer
-- (found via live testing: schedule_pickup correctly rolled back its
-- pickup_requests insert too, since it's all one RPC transaction).

create policy "service_history_insert_own" on public.service_history
  for insert with check (customer_id = auth.uid());
