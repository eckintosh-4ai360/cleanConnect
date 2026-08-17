-- CleanConnect: seed the 4 known pricing plans + the singleton app_settings row.
-- Matches the fixed-ID docs (weekly/biweekly/monthly/payg) the admin panel's
-- Payments.jsx already writes today. Idempotent so this migration is safe to
-- re-run.

insert into public.pricing_plans (slug, name, frequency, description, is_payg, prices)
values
  ('weekly', 'Weekly Plan', 'Weekly', 'Collection once every week', false,
    '{"120L": 40, "240L": 60, "360L": 85}'::jsonb),
  ('biweekly', 'Bi-Weekly Plan', 'Bi-Weekly', 'Collection once every two weeks', false,
    '{"120L": 70, "240L": 100, "360L": 140}'::jsonb),
  ('monthly', 'Monthly Plan', 'Monthly', 'Collection once every month', false,
    '{"120L": 120, "240L": 170, "360L": 230}'::jsonb),
  ('payg', 'Pay As You Go', 'On Demand', 'Pay per pickup, no subscription', true,
    '{"120L": 15, "240L": 22, "360L": 30}'::jsonb)
on conflict (slug) do nothing;

insert into public.app_settings (id, weekly_fee, biweekly_fee, monthly_fee, payg_fee, payg_ratio)
values (true, 40, 70, 120, 15, 1.30)
on conflict (id) do nothing;
