-- Local-only demo rows. Never applied to kasat-production by `supabase db push`.
-- `supabase db reset` loads this file after migrations.

insert into public.stations (
  id, code, name, display_name, region, country_code, general_area, alert_email, jurisdiction
)
values (
  '11111111-1111-1111-1111-111111111111',
  'STN-ADD-BOLE',
  'Bole Sub-City Station',
  'Bole Sub-City Station',
  'Addis Ababa',
  'ET',
  'Bole',
  'alerts@bole.kasat.local',
  'Addis Ababa — Bole'
)
on conflict (code) do nothing;
