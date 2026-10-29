-- Kasat law-enforcement portal — additive schema
--
-- Safe to run on a database that already has supabase/schema.sql from the
-- mobile-app repo. Does not change anonymous insert or tracking-code lookup.
-- The survivor-facing table remains `incidents` (there is no `reports` table).
--
-- Apply in the Supabase SQL editor after the base schema.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------- portal enums ----

do $$ begin
  create type case_status as enum ('new', 'acknowledged', 'in_progress', 'resolved');
exception
  when duplicate_object then null;
end $$;

-- --------------------------------------------------------------- stations ----
-- Stations become organisational units (not auth identities). Officers log in
-- individually. Dropping the auth.users FK is required for that split.

alter table stations drop constraint if exists stations_id_fkey;
alter table stations alter column id set default gen_random_uuid();

alter table stations add column if not exists name text;
alter table stations add column if not exists region text;
alter table stations add column if not exists country_code text;
alter table stations add column if not exists general_area text;

update stations
   set name = coalesce(name, display_name),
       country_code = coalesce(country_code, 'ET'),
       general_area = coalesce(nullif(general_area, ''), coalesce(jurisdiction, 'Addis Ababa'))
 where true;

alter table stations alter column name set not null;
alter table stations alter column country_code set not null;
alter table stations alter column general_area set not null;

alter table stations drop constraint if exists stations_country_code_check;
alter table stations add constraint stations_country_code_check
  check (country_code ~ '^[A-Z]{2}$');

drop policy if exists "stations read own row" on stations;

-- ----------------------------------------------------------------- teams ----

create table if not exists officer_teams (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references stations (id) on delete cascade,
  name text not null default 'GBV response unit',
  created_at timestamptz not null default now()
);

-- --------------------------------------------------------------- officers ----

create table if not exists officers (
  id uuid primary key references auth.users (id) on delete cascade,
  team_id uuid not null references officer_teams (id) on delete restrict,
  name text not null,
  badge_id text not null unique,
  created_at timestamptz not null default now()
);

create index if not exists officers_team_idx on officers (team_id);

create or replace function officer_station_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select t.station_id
    from officers o
    join officer_teams t on t.id = o.team_id
   where o.id = auth.uid()
$$;

create or replace function current_officer_team_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select team_id from officers where id = auth.uid()
$$;

revoke all on function officer_station_id() from public, anon;
revoke all on function current_officer_team_id() from public, anon;
grant execute on function officer_station_id() to authenticated;
grant execute on function current_officer_team_id() to authenticated;

alter table officer_teams enable row level security;
alter table officers enable row level security;

drop policy if exists "officers read own station" on stations;
create policy "officers read own station"
  on stations for select
  to authenticated
  using (id = officer_station_id());

drop policy if exists "officers read own team" on officer_teams;
create policy "officers read own team"
  on officer_teams for select
  to authenticated
  using (station_id = officer_station_id());

drop policy if exists "officers read teammates" on officers;
create policy "officers read teammates"
  on officers for select
  to authenticated
  using (team_id = current_officer_team_id());

-- ------------------------------------------------------------- incidents ----

alter table incidents add column if not exists station_id uuid references stations (id);
alter table incidents add column if not exists claimed_by_officer_id uuid references officers (id);
alter table incidents add column if not exists case_status case_status not null default 'new';
alter table incidents add column if not exists status_updated_at timestamptz;
alter table incidents add column if not exists claimed_at timestamptz;
alter table incidents add column if not exists identity_revealed_by_user boolean not null default false;
alter table incidents add column if not exists general_area text;

update incidents
   set general_area = coalesce(general_area, 'Addis Ababa'),
       status_updated_at = coalesce(status_updated_at, submitted_at)
 where true;

alter table incidents alter column general_area set not null;

create index if not exists incidents_station_queue_idx
  on incidents (station_id, case_status, submitted_at desc);
create index if not exists incidents_claimed_idx
  on incidents (claimed_by_officer_id, claimed_at);

drop policy if exists "operators read all" on incidents;
drop policy if exists "operators update status" on incidents;
drop policy if exists "officers read station incidents" on incidents;

-- Station-scoped row access. Exact coordinates are stripped by column grants
-- and only returned through security-definer RPCs after claim.
create policy "officers read station incidents"
  on incidents for select
  to authenticated
  using (station_id = officer_station_id());

revoke select on incidents from authenticated;
grant select (
  tracking_id,
  category,
  description,
  priority,
  status,
  case_status,
  location_precision,
  general_area,
  country_code,
  assigned_station,
  station_id,
  claimed_by_officer_id,
  claimed_at,
  submitted_at,
  updated_at,
  status_updated_at,
  identity_revealed_by_user
) on incidents to authenticated;

-- Anon insert still cannot set a station. Match after insert so WITH CHECK
-- (assigned_station is null) continues to pass.
create or replace function match_incident_station()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  matched stations%rowtype;
begin
  if new.general_area is null or btrim(new.general_area) = '' then
    new.general_area := case new.country_code
      when 'ET' then 'Addis Ababa'
      else new.country_code
    end;
  end if;

  return new;
end;
$$;

drop trigger if exists incidents_default_area on incidents;
create trigger incidents_default_area
  before insert on incidents
  for each row execute function match_incident_station();

create or replace function assign_incident_station()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  sid uuid;
  scode text;
begin
  new.station_id := null;
  new.assigned_station := null;

  select s.id, s.code
    into sid, scode
    from public.stations s
   where s.country_code = new.country_code
     and (
       position(lower(coalesce(s.general_area, '')) in lower(coalesce(new.general_area, ''))) > 0
       or position(lower(coalesce(new.general_area, '')) in lower(coalesce(s.general_area, ''))) > 0
     )
   order by length(s.general_area) desc
   limit 1;

  if sid is null then
    select s.id, s.code
      into sid, scode
      from public.stations s
     where s.country_code = new.country_code
     order by s.created_at
     limit 1;
  end if;

  if sid is not null then
    update public.incidents
       set station_id = sid,
           assigned_station = scode
     where tracking_id = new.tracking_id;
  end if;

  return new;
end;
$$;

drop trigger if exists incidents_assign_station on incidents;
create trigger incidents_assign_station
  after insert on incidents
  for each row execute function assign_incident_station();

-- Do not let the public trail copy officer names into assigned_station.
create or replace function sync_incident_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update incidents
     set status = new.status,
         updated_at = new.at
   where tracking_id = new.tracking_id;
  return new;
end;
$$;

-- ----------------------------------------------------------- internal notes --

create table if not exists officer_case_notes (
  id uuid primary key default gen_random_uuid(),
  tracking_id text not null references incidents (tracking_id) on delete cascade,
  officer_id uuid not null references officers (id),
  case_status case_status not null,
  note text not null check (char_length(btrim(note)) >= 3),
  at timestamptz not null default now()
);

create index if not exists officer_case_notes_tracking_idx
  on officer_case_notes (tracking_id, at);

alter table officer_case_notes enable row level security;

create policy "officers read station notes"
  on officer_case_notes for select
  to authenticated
  using (
    tracking_id in (
      select tracking_id from incidents where station_id = officer_station_id()
    )
  );

-- ----------------------------------------------------- revealed identities --
-- Written only from her side of the product when she opts in. Never joined
-- to Vent Here. Portal may read a row only via RPC, and only the claimant.

create table if not exists revealed_identities (
  tracking_id text primary key references incidents (tracking_id) on delete cascade,
  channel text not null check (channel in ('phone', 'email')),
  handle text not null,
  revealed_at timestamptz not null default now()
);

alter table revealed_identities enable row level security;
-- No authenticated SELECT policy: access is RPC-only after identity_revealed_by_user.

-- ----------------------------------------------------------- access audit ----

create table if not exists access_audit_log (
  id uuid primary key default gen_random_uuid(),
  officer_id uuid not null references officers (id),
  tracking_id text not null references incidents (tracking_id) on delete cascade,
  event_type text not null check (event_type in ('location_unlock', 'identity_reveal_view')),
  at timestamptz not null default now()
);

create index if not exists access_audit_log_case_idx
  on access_audit_log (tracking_id, event_type, at desc);

alter table access_audit_log enable row level security;

create policy "officers read own audit"
  on access_audit_log for select
  to authenticated
  using (officer_id = auth.uid());

-- --------------------------------------------------------------- RPCs ------

create or replace function current_officer_profile()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  select jsonb_build_object(
           'id', o.id,
           'name', o.name,
           'badgeId', o.badge_id,
           'email', au.email,
           'teamId', o.team_id,
           'station', jsonb_build_object(
             'id', s.id,
             'code', s.code,
             'name', s.name,
             'region', s.region,
             'countryCode', s.country_code,
             'generalArea', s.general_area
           )
         )
    into result
    from officers o
    join officer_teams t on t.id = o.team_id
    join stations s on s.id = t.station_id
    join auth.users au on au.id = o.id
   where o.id = auth.uid();

  if result is null then
    raise exception 'not an officer';
  end if;
  return result;
end;
$$;

create or replace function list_teammates()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', o.id,
           'name', o.name,
           'badgeId', o.badge_id
         ) order by o.name), '[]'::jsonb)
    from officers o
   where o.team_id = (select team_id from officers where id = auth.uid());
$$;

create or replace function officer_queue()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  sid uuid := officer_station_id();
  oid uuid := auth.uid();
begin
  if sid is null then
    raise exception 'not an officer';
  end if;

  return (
    select coalesce(jsonb_agg(row_to_json(q)::jsonb order by q.submitted_at desc), '[]'::jsonb)
      from (
        select
          i.tracking_id as "trackingId",
          i.category,
          i.description,
          i.priority,
          i.status,
          i.case_status as "caseStatus",
          i.country_code as "countryCode",
          i.general_area as "generalArea",
          i.submitted_at as "submittedAt",
          i.updated_at as "updatedAt",
          i.status_updated_at as "statusUpdatedAt",
          i.claimed_at as "claimedAt",
          i.claimed_by_officer_id as "claimedByOfficerId",
          c.name as "claimedByName",
          i.identity_revealed_by_user as "identityRevealedByUser",
          (select count(*) from attachments a where a.tracking_id = i.tracking_id)::int as "attachmentCount",
          case when i.claimed_by_officer_id = oid then i.latitude else null end as latitude,
          case when i.claimed_by_officer_id = oid then i.longitude else null end as longitude,
          case when i.claimed_by_officer_id = oid then i.location_precision else null end as "locationPrecision",
          case when i.claimed_by_officer_id = oid then i.location_note else null end as "locationDetail"
        from incidents i
        left join officers c on c.id = i.claimed_by_officer_id
        where i.station_id = sid
      ) q
  );
end;
$$;

create or replace function get_case_detail(p_tracking_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  sid uuid := officer_station_id();
  oid uuid := auth.uid();
  rec incidents%rowtype;
  is_claimant boolean;
  payload jsonb;
begin
  if sid is null then
    raise exception 'not an officer';
  end if;

  select * into rec from incidents where tracking_id = p_tracking_id;
  if not found or rec.station_id is distinct from sid then
    raise exception 'not found';
  end if;

  is_claimant := rec.claimed_by_officer_id = oid;

  if is_claimant and rec.identity_revealed_by_user then
    insert into access_audit_log (officer_id, tracking_id, event_type)
    values (oid, rec.tracking_id, 'identity_reveal_view');
  end if;

  select jsonb_build_object(
    'trackingId', rec.tracking_id,
    'category', rec.category,
    'description', rec.description,
    'priority', rec.priority,
    'status', rec.status,
    'caseStatus', rec.case_status,
    'countryCode', rec.country_code,
    'generalArea', rec.general_area,
    'submittedAt', rec.submitted_at,
    'updatedAt', rec.updated_at,
    'statusUpdatedAt', rec.status_updated_at,
    'claimedAt', rec.claimed_at,
    'claimedByOfficerId', rec.claimed_by_officer_id,
    'claimedByName', (select name from officers where id = rec.claimed_by_officer_id),
    'identityRevealedByUser', rec.identity_revealed_by_user,
    'attachmentCount', (select count(*) from attachments a where a.tracking_id = rec.tracking_id),
    'attachments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'label', a.label,
        'mimeType', a.mime_type,
        'byteSize', a.byte_size,
        'strippedMetadata', a.stripped_metadata
      ) order by a.label)
      from attachments a
      where a.tracking_id = rec.tracking_id
    ), '[]'::jsonb),
    'latitude', case when is_claimant then rec.latitude else null end,
    'longitude', case when is_claimant then rec.longitude else null end,
    'locationPrecision', case when is_claimant then rec.location_precision else null end,
    'locationDetail', case when is_claimant then rec.location_note else null end,
    'locationUnlockedAt', case when is_claimant then rec.claimed_at else null end,
    'revealedIdentity', case
      when is_claimant and rec.identity_revealed_by_user then (
        select jsonb_build_object(
          'channel', r.channel,
          'handle', r.handle,
          'revealedAt', r.revealed_at
        )
        from revealed_identities r
        where r.tracking_id = rec.tracking_id
      )
      else null
    end,
    'officerNotes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', n.id,
        'caseStatus', n.case_status,
        'note', n.note,
        'at', n.at,
        'officerName', o.name
      ) order by n.at)
      from officer_case_notes n
      join officers o on o.id = n.officer_id
      where n.tracking_id = rec.tracking_id
    ), '[]'::jsonb),
    'publicHistory', coalesce((
      select jsonb_agg(jsonb_build_object(
        'status', e.status,
        'at', e.at,
        'message', e.note
      ) order by e.at)
      from status_events e
      where e.tracking_id = rec.tracking_id
    ), '[]'::jsonb)
  ) into payload;

  return payload;
end;
$$;

create or replace function claim_incident(p_tracking_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  sid uuid := officer_station_id();
  oid uuid := auth.uid();
  rec incidents%rowtype;
begin
  if sid is null then
    raise exception 'not an officer';
  end if;

  select * into rec from incidents where tracking_id = p_tracking_id for update;
  if not found or rec.station_id is distinct from sid then
    raise exception 'not found';
  end if;
  if rec.claimed_by_officer_id is not null then
    raise exception 'already claimed';
  end if;

  update incidents
     set claimed_by_officer_id = oid,
         claimed_at = now(),
         updated_at = now()
   where tracking_id = p_tracking_id;

  insert into access_audit_log (officer_id, tracking_id, event_type)
  values (oid, p_tracking_id, 'location_unlock');

  return get_case_detail(p_tracking_id);
end;
$$;

create or replace function update_case_status(p_tracking_id text, p_status case_status, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  sid uuid := officer_station_id();
  oid uuid := auth.uid();
  rec incidents%rowtype;
  public_status incident_status;
  public_note text;
  scode text;
begin
  if sid is null then
    raise exception 'not an officer';
  end if;
  if char_length(btrim(coalesce(p_note, ''))) < 3 then
    raise exception 'note required';
  end if;

  select * into rec from incidents where tracking_id = p_tracking_id for update;
  if not found or rec.station_id is distinct from sid then
    raise exception 'not found';
  end if;
  if rec.claimed_by_officer_id is distinct from oid then
    raise exception 'not claimant';
  end if;

  public_status := case p_status
    when 'new' then 'RECEIVED'::incident_status
    when 'acknowledged' then 'UNDER_INVESTIGATION'::incident_status
    when 'in_progress' then 'UNDER_INVESTIGATION'::incident_status
    when 'resolved' then 'RESOLVED'::incident_status
  end;
  public_note := case p_status
    when 'acknowledged' then 'An officer has been assigned'
    when 'in_progress' then 'In progress'
    when 'resolved' then 'Resolved'
    else null
  end;

  select code into scode from stations where id = sid;

  update incidents
     set case_status = p_status,
         status_updated_at = now(),
         updated_at = now()
   where tracking_id = p_tracking_id;

  insert into officer_case_notes (tracking_id, officer_id, case_status, note)
  values (p_tracking_id, oid, p_status, btrim(p_note));

  if public_note is not null then
    insert into status_events (tracking_id, status, actor, note)
    values (p_tracking_id, public_status, coalesce(scode, 'ASSIGNED'), public_note);
  end if;

  return get_case_detail(p_tracking_id);
end;
$$;

create or replace function reassign_incident(p_tracking_id text, p_to_officer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sid uuid := public.officer_station_id();
  oid uuid := auth.uid();
  rec public.incidents%rowtype;
  target_station uuid;
begin
  if sid is null then
    raise exception 'not an officer';
  end if;

  select * into rec from public.incidents where tracking_id = p_tracking_id for update;
  if not found or rec.station_id is distinct from sid then
    raise exception 'not found';
  end if;
  if rec.claimed_by_officer_id is distinct from oid then
    raise exception 'not claimant';
  end if;

  select coalesce(o.station_id, t.station_id) into target_station
    from public.officers o
    left join public.officer_teams t on t.id = o.team_id
   where o.id = p_to_officer_id;

  if target_station is distinct from sid then
    raise exception 'not on this station';
  end if;

  update public.incidents
     set claimed_by_officer_id = p_to_officer_id,
         updated_at = now()
   where tracking_id = p_tracking_id;

  insert into public.access_audit_log (officer_id, tracking_id, event_type)
  values (oid, p_tracking_id, 'location_unlock');

  insert into public.officer_case_notes (tracking_id, officer_id, case_status, note)
  values (
    p_tracking_id,
    oid,
    rec.case_status,
    'Reassigned to another officer on the GBV unit.'
  );

  return public.get_case_detail(p_tracking_id);
end;
$$;

revoke all on function current_officer_profile() from public, anon;
revoke all on function list_teammates() from public, anon;
revoke all on function officer_queue() from public, anon;
revoke all on function get_case_detail(text) from public, anon;
revoke all on function claim_incident(text) from public, anon;
revoke all on function update_case_status(text, case_status, text) from public, anon;
revoke all on function reassign_incident(text, uuid) from public, anon;

grant execute on function current_officer_profile() to authenticated;
grant execute on function list_teammates() to authenticated;
grant execute on function officer_queue() to authenticated;
grant execute on function get_case_detail(text) to authenticated;
grant execute on function claim_incident(text) to authenticated;
grant execute on function update_case_status(text, case_status, text) to authenticated;
grant execute on function reassign_incident(text, uuid) to authenticated;

-- Replace attachment / evidence / trail operator policies (were station-as-user).

drop policy if exists "operators read trail" on status_events;
drop policy if exists "operators append trail" on status_events;
drop policy if exists "operators read attachments" on attachments;
drop policy if exists "operators read evidence" on storage.objects;

create policy "officers read station trail"
  on status_events for select
  to authenticated
  using (
    tracking_id in (
      select tracking_id from incidents
       where station_id = officer_station_id()
    )
  );

create policy "officers read station attachments"
  on attachments for select
  to authenticated
  using (
    tracking_id in (
      select tracking_id from incidents
       where station_id = officer_station_id()
    )
  );

create policy "officers read evidence"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'incident-evidence'
    and officer_station_id() is not null
  );

-- --------------------------------------------------------------- seed ------
-- Pilot station. Create officer Auth users in the dashboard, then insert
-- matching rows into officers (see seed.sql).

insert into stations (code, name, region, country_code, general_area, display_name, jurisdiction)
values (
  'STN-ADD-BOLE',
  'Bole Sub-City Station',
  'Addis Ababa',
  'ET',
  'Bole',
  'Bole Sub-City Station',
  'Addis Ababa — Bole'
)
on conflict (code) do update
  set name = excluded.name,
      region = excluded.region,
      country_code = excluded.country_code,
      general_area = excluded.general_area;

insert into officer_teams (id, station_id, name)
select 'a0e1b2c3-d4e5-4f67-8899-000000000001'::uuid, s.id, 'GBV response unit'
  from stations s
 where s.code = 'STN-ADD-BOLE'
   and not exists (
     select 1 from officer_teams t where t.station_id = s.id
   );
