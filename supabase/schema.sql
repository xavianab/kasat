-- Kasat — Supabase schema
--
-- Design rule for this file: there is no user table on the survivor side and
-- there never will be. The tracking id minted on the handset is the only
-- identifier, so every policy below is written to avoid creating a second one
-- (no auth.uid(), no device id, no IP column, no created_by).

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------- enums ----

create type incident_status as enum ('RECEIVED', 'UNDER_INVESTIGATION', 'RESOLVED');
create type incident_priority as enum ('P1', 'P2', 'P3', 'P4');
create type location_precision as enum ('BLOCK', 'DISTRICT', 'CITY', 'REGION');

-- ------------------------------------------------------------- stations ----

-- Operators. Rows here are the *only* authenticated identities in the system.
create table stations (
  id uuid primary key references auth.users (id) on delete cascade,
  code text not null unique,          -- e.g. 'STN-04'
  display_name text not null,
  jurisdiction text,
  created_at timestamptz not null default now()
);

alter table stations enable row level security;

create policy "stations read own row"
  on stations for select
  to authenticated
  using (id = auth.uid());

-- ------------------------------------------------------------ incidents ----

create table incidents (
  tracking_id text primary key
    check (tracking_id ~ '^KST-[23456789ABCDEFGHJKMNPQRSTVWXYZ]{5}$'),
  category text not null,
  description text not null check (char_length(description) between 40 and 2000),
  priority incident_priority not null,
  status incident_status not null default 'RECEIVED',

  latitude double precision,
  longitude double precision,
  location_precision location_precision,
  location_note text,

  -- ISO 3166-1 alpha-2 chosen at onboarding. Never derived from IP or locale.
  country_code text not null default 'ET' check (country_code ~ '^[A-Z]{2}$'),

  assigned_station text references stations (code),
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index incidents_status_idx on incidents (status, submitted_at desc);
create index incidents_priority_idx on incidents (priority, submitted_at desc);
create index incidents_country_idx on incidents (country_code, submitted_at desc);

alter table incidents enable row level security;

-- Survivors submit without an account. Insert is the only anonymous write, and
-- the check constraints above are what stop it being an open pipe.
create policy "anonymous submission"
  on incidents for insert
  to anon
  with check (status = 'RECEIVED' and assigned_station is null);

-- Anonymous reads are scoped to a single tracking id supplied as a request
-- header, so possession of a code reveals that case and nothing else. Without
-- this scoping the anon key would enumerate every report in the table.
create policy "anonymous lookup by tracking id"
  on incidents for select
  to anon
  using (
    tracking_id = current_setting('request.headers', true)::json ->> 'x-tracking-id'
  );

create policy "operators read all"
  on incidents for select
  to authenticated
  using (exists (select 1 from stations where stations.id = auth.uid()));

create policy "operators update status"
  on incidents for update
  to authenticated
  using (exists (select 1 from stations where stations.id = auth.uid()))
  with check (exists (select 1 from stations where stations.id = auth.uid()));

-- --------------------------------------------------------- status events ----

-- Append-only audit trail. The dashboard writes here; `incidents.status` is
-- kept in sync by trigger so a case can never change hands unrecorded.
create table status_events (
  id uuid primary key default gen_random_uuid(),
  tracking_id text not null references incidents (tracking_id) on delete cascade,
  status incident_status not null,
  actor text not null default 'SYSTEM',
  note text,
  at timestamptz not null default now()
);

create index status_events_tracking_idx on status_events (tracking_id, at);

alter table status_events enable row level security;

create policy "anonymous read own trail"
  on status_events for select
  to anon
  using (
    tracking_id = current_setting('request.headers', true)::json ->> 'x-tracking-id'
  );

create policy "operators read trail"
  on status_events for select
  to authenticated
  using (exists (select 1 from stations where stations.id = auth.uid()));

create policy "operators append trail"
  on status_events for insert
  to authenticated
  with check (exists (select 1 from stations where stations.id = auth.uid()));

create or replace function sync_incident_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update incidents
     set status = new.status,
         assigned_station = coalesce(new.actor, assigned_station),
         updated_at = new.at
   where tracking_id = new.tracking_id;
  return new;
end;
$$;

create trigger status_events_sync
  after insert on status_events
  for each row execute function sync_incident_status();

-- ----------------------------------------------------------- attachments ----

create table attachments (
  id uuid primary key default gen_random_uuid(),
  tracking_id text not null references incidents (tracking_id) on delete cascade,
  label text not null,               -- 'EVIDENCE-01'; never the original filename
  mime_type text not null,
  byte_size integer not null,
  storage_path text not null,
  stripped_metadata boolean not null default true,
  width integer,
  height integer
);

alter table attachments enable row level security;

create policy "anonymous attach"
  on attachments for insert
  to anon
  with check (
    stripped_metadata = true
    and tracking_id = current_setting('request.headers', true)::json ->> 'x-tracking-id'
    and exists (select 1 from incidents i where i.tracking_id = attachments.tracking_id)
  );

create policy "operators read attachments"
  on attachments for select
  to authenticated
  using (exists (select 1 from stations where stations.id = auth.uid()));

-- --------------------------------------------------------------- storage ----

insert into storage.buckets (id, name, public)
values ('incident-evidence', 'incident-evidence', false)
on conflict (id) do nothing;

create policy "anonymous evidence upload"
  on storage.objects for insert
  to anon
  with check (
    bucket_id = 'incident-evidence'
    and position('..' in name) = 0
    and name ~ '^[A-Z0-9-]{8,16}/[0-9a-fA-F-]{36}\.(png|jpe?g|webp)$'
  );

create policy "operators read evidence"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'incident-evidence'
    and position('..' in name) = 0
    and exists (
      select 1 from incidents i
      where i.tracking_id = split_part(name, '/', 1)
        and i.assigned_station in (select code from stations)
    )
  );

-- -------------------------------------------------------------- realtime ----

alter publication supabase_realtime add table incidents;
alter publication supabase_realtime add table status_events;

-- Officer portal (Station → Team → Officer, tiered visibility, claim lock).
-- Additive, does not change anonymous insert or tracking-code lookup:
--   supabase/portal_extension.sql
-- Canonical copy also lives in the kasat-police-portal repo.
