-- Shared Kasat reports table — survivor app + officer portal.
-- Additive. Does not store names, phones, device ids, or IPs.
-- Police never see status = draft.

create extension if not exists "pgcrypto";

do $$ begin
  create type report_status as enum ('draft', 'sent', 'under_review', 'resolved');
exception
  when duplicate_object then null;
end $$;

-- Station alert channels (police contact, not survivor).
alter table if exists stations add column if not exists alert_email text;
alter table if exists stations add column if not exists alert_phone text;

create table if not exists stations (
  id uuid primary key default gen_random_uuid(),
  code text unique,
  name text,
  display_name text,
  jurisdiction text,
  region text,
  country_code text default 'ET',
  general_area text default 'Bole',
  alert_email text,
  alert_phone text,
  created_at timestamptz not null default now()
);

alter table stations add column if not exists alert_email text;
alter table stations add column if not exists alert_phone text;

create table if not exists officer_teams (
  id uuid primary key default gen_random_uuid(),
  station_id uuid references stations (id) on delete cascade,
  name text not null default 'GBV response unit',
  created_at timestamptz not null default now()
);

create table if not exists officers (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  badge_id text not null unique,
  team_id uuid,
  station_id uuid references stations (id),
  created_at timestamptz not null default now()
);

create or replace function officer_station_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(o.station_id, t.station_id)
    from officers o
    left join officer_teams t on t.id = o.team_id
   where o.id = auth.uid()
$$;

revoke all on function officer_station_id() from public, anon;
grant execute on function officer_station_id() to authenticated;

-- ---------------------------------------------------------------- reports --

create table if not exists reports (
  id uuid primary key default gen_random_uuid(),
  tracking_code text not null unique
    check (tracking_code ~ '^KST-[23456789ABCDEFGHJKMNPQRSTVWXYZ]{5}$'),
  incident_type text not null,
  approx_location text,
  description text not null check (char_length(btrim(description)) between 40 and 2000),
  photo_url text,
  status report_status not null default 'draft',
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  station_id uuid references stations (id)
);

create index if not exists reports_station_status_idx
  on reports (station_id, status, sent_at desc);
create index if not exists reports_tracking_idx on reports (tracking_code);

alter table reports enable row level security;

drop policy if exists "survivor insert draft" on reports;
drop policy if exists "survivor lookup by tracking code" on reports;
drop policy if exists "survivor send by tracking code" on reports;
drop policy if exists "officers read sent reports" on reports;
drop policy if exists "officers update status only" on reports;

create policy "survivor insert draft"
  on reports for insert
  to anon
  with check (status = 'draft' and sent_at is null);

create policy "survivor lookup by tracking code"
  on reports for select
  to anon
  using (
    tracking_code = current_setting('request.headers', true)::json ->> 'x-tracking-code'
  );

create policy "survivor send by tracking code"
  on reports for update
  to anon
  using (
    tracking_code = current_setting('request.headers', true)::json ->> 'x-tracking-code'
  )
  with check (
    tracking_code = current_setting('request.headers', true)::json ->> 'x-tracking-code'
    and status in ('draft', 'sent')
  );

create policy "officers read sent reports"
  on reports for select
  to authenticated
  using (
    status <> 'draft'
    and station_id = officer_station_id()
  );

create policy "officers update status only"
  on reports for update
  to authenticated
  using (
    status <> 'draft'
    and station_id = officer_station_id()
  )
  with check (
    status <> 'draft'
    and station_id = officer_station_id()
  );

revoke all on reports from authenticated;
grant select on reports to authenticated;
grant update (status) on reports to authenticated;
grant insert, select, update on reports to anon;

-- Anon cannot change content after insert.
create or replace function reports_write_guard()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and auth.role() = 'anon' then
    if new.tracking_code is distinct from old.tracking_code
       or new.incident_type is distinct from old.incident_type
       or new.approx_location is distinct from old.approx_location
       or new.description is distinct from old.description
       or new.photo_url is distinct from old.photo_url
       or new.station_id is distinct from old.station_id then
      raise exception 'survivor may only change status';
    end if;
    if old.status = 'draft' and new.status = 'sent' then
      new.sent_at := coalesce(new.sent_at, now());
    elsif new.status is distinct from old.status then
      raise exception 'survivor may only send a draft';
    end if;
  end if;

  if tg_op = 'UPDATE' and auth.role() = 'authenticated' then
    if new.tracking_code is distinct from old.tracking_code
       or new.incident_type is distinct from old.incident_type
       or new.approx_location is distinct from old.approx_location
       or new.description is distinct from old.description
       or new.photo_url is distinct from old.photo_url
       or new.station_id is distinct from old.station_id
       or new.sent_at is distinct from old.sent_at
       or new.created_at is distinct from old.created_at then
      raise exception 'officers may only update status';
    end if;
    if new.status = 'draft' then
      raise exception 'cannot revert to draft';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists reports_write_guard on reports;
create trigger reports_write_guard
  before update on reports
  for each row execute function reports_write_guard();

create or replace function reports_assign_station()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.station_id is null then
    select s.id into new.station_id
      from stations s
     where coalesce(s.country_code, 'ET') = 'ET'
     order by s.created_at
     limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists reports_assign_station on reports;
create trigger reports_assign_station
  before insert on reports
  for each row execute function reports_assign_station();

-- -------------------------------------------------------------- audit log --

create table if not exists report_audit_log (
  id uuid primary key default gen_random_uuid(),
  officer_id uuid not null references officers (id),
  report_id uuid not null references reports (id) on delete cascade,
  action text not null check (action in ('view', 'update_status')),
  created_at timestamptz not null default now()
);

create index if not exists report_audit_log_report_idx
  on report_audit_log (report_id, created_at desc);

alter table report_audit_log enable row level security;

drop policy if exists "officers read own audit" on report_audit_log;
create policy "officers read own audit"
  on report_audit_log for select
  to authenticated
  using (officer_id = auth.uid());

create or replace function log_report_access(p_report_id uuid, p_action text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not an officer';
  end if;
  if not exists (
    select 1 from reports r
     where r.id = p_report_id
       and r.status <> 'draft'
       and r.station_id = officer_station_id()
  ) then
    raise exception 'not found';
  end if;
  insert into report_audit_log (officer_id, report_id, action)
  values (auth.uid(), p_report_id, p_action);
end;
$$;

revoke all on function log_report_access(uuid, text) from public, anon;
grant execute on function log_report_access(uuid, text) to authenticated;

-- Generic officer alerts. Body is fixed; never copy report fields here.
create table if not exists alert_outbox (
  id uuid primary key default gen_random_uuid(),
  station_id uuid references stations (id),
  channel text not null check (channel in ('email', 'sms')),
  body text not null,
  created_at timestamptz not null default now()
);

alter table alert_outbox enable row level security;

create or replace function enqueue_station_alert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and old.status = 'draft'
     and new.status = 'sent' then
    insert into alert_outbox (station_id, channel, body)
    values (
      new.station_id,
      'email',
      'New Kasat report received — log in to view.'
    );
    if exists (
      select 1 from stations s
       where s.id = new.station_id
         and s.alert_phone is not null
         and btrim(s.alert_phone) <> ''
    ) then
      insert into alert_outbox (station_id, channel, body)
      values (
        new.station_id,
        'sms',
        'New Kasat report received — log in to view.'
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists reports_enqueue_alert on reports;
create trigger reports_enqueue_alert
  after update on reports
  for each row execute function enqueue_station_alert();

alter table reports replica identity full;
do $$ begin
  alter publication supabase_realtime add table reports;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

-- Photos: path only, never original filenames with identity.
insert into storage.buckets (id, name, public)
values ('report-photos', 'report-photos', false)
on conflict (id) do nothing;

drop policy if exists "anonymous report photo upload" on storage.objects;
create policy "anonymous report photo upload"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'report-photos');

drop policy if exists "officers read report photos" on storage.objects;
create policy "officers read report photos"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'report-photos' and officer_station_id() is not null);

-- Pilot station
insert into stations (id, code, name, display_name, region, country_code, general_area, alert_email, jurisdiction)
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
on conflict (code) do update
  set alert_email = coalesce(stations.alert_email, excluded.alert_email),
      general_area = excluded.general_area,
      name = excluded.name;

-- Database Webhook (hosted project): table `reports`, event UPDATE,
-- URL https://<project>.supabase.co/functions/v1/notify-station
-- JWT off (verify_jwt = false). The function body is always
-- "New Kasat report received — log in to view." — never report fields.
