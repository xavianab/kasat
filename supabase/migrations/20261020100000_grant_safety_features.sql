-- Grant submission safety features:
-- 1. "I'm in Danger" URGENT reports + 30-minute live location + audit logging
-- 2. Separate one-way `report_identities` table (anonymous -> named, irreversible)
-- 3. Tamper-evident evidence SHA-256 integrity hash alongside server UTC created_at

-- ---------------------------------------------------------------------------
-- 1. Emergency & Evidence Integrity columns on `public.reports`
-- ---------------------------------------------------------------------------

alter table public.reports
  add column if not exists is_emergency boolean not null default false,
  add column if not exists live_latitude double precision,
  add column if not exists live_longitude double precision,
  add column if not exists location_updated_at timestamptz,
  add column if not exists live_location_active boolean not null default false,
  add column if not exists evidence_sha256 text,
  add column if not exists identity_revealed boolean not null default false;

create index if not exists reports_emergency_idx
  on public.reports (station_id, is_emergency desc, sent_at desc);

-- Allow anon to insert EITHER a normal draft OR an immediate "I'm in Danger"
-- emergency row (status = 'sent', is_emergency = true).
drop policy if exists "survivor insert draft" on public.reports;
create policy "survivor insert draft"
  on public.reports for insert
  to anon
  with check (
    (status = 'draft' and sent_at is null and is_emergency = false)
    or (is_emergency = true and status = 'sent')
  );

-- Update write guard so:
-- (a) Anon can transition draft -> sent (and attach retried photo_url / evidence_sha256)
-- (b) Anon can update live_latitude, live_longitude, location_updated_at, and
--     live_location_active on an active emergency report matching x-tracking-code
-- (c) Only the security-definer RPC can flip identity_revealed = true
create or replace function public.reports_write_guard()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and auth.role() = 'anon' then
    if new.tracking_code is distinct from old.tracking_code
       or new.incident_type is distinct from old.incident_type
       or new.approx_location is distinct from old.approx_location
       or new.description is distinct from old.description
       or new.station_id is distinct from old.station_id
       or new.is_emergency is distinct from old.is_emergency then
      raise exception 'survivor may not alter immutable report fields';
    end if;

    if new.identity_revealed is distinct from old.identity_revealed
       and current_setting('kasat.allow_identity_flag', true) is distinct from '1' then
      raise exception 'identity_revealed can only be set via reveal_report_identity';
    end if;

    -- Case 1: Normal or queued draft being sent to police (allows late photo upload)
    if old.status = 'draft' and new.status = 'sent' then
      new.sent_at := coalesce(new.sent_at, now());
      return new;
    end if;

    -- Case 2: Live location update or stop on an emergency report
    if old.is_emergency = true and new.status = old.status then
      if new.photo_url is distinct from old.photo_url
         or new.evidence_sha256 is distinct from old.evidence_sha256 then
        raise exception 'cannot change photo during live location update';
      end if;
      return new;
    end if;

    if new.status is distinct from old.status then
      raise exception 'survivor may only send a draft';
    end if;
  end if;

  if tg_op = 'UPDATE' and auth.role() = 'authenticated' then
    if new.tracking_code is distinct from old.tracking_code
       or new.incident_type is distinct from old.incident_type
       or new.approx_location is distinct from old.approx_location
       or new.description is distinct from old.description
       or new.photo_url is distinct from old.photo_url
       or new.evidence_sha256 is distinct from old.evidence_sha256
       or new.station_id is distinct from old.station_id
       or new.sent_at is distinct from old.sent_at
       or new.created_at is distinct from old.created_at
       or new.is_emergency is distinct from old.is_emergency then
      raise exception 'officers may only update status';
    end if;
    if new.status = 'draft' then
      raise exception 'cannot revert to draft';
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Audit log updates for emergency activations & identity reveal
-- ---------------------------------------------------------------------------

alter table public.report_audit_log
  alter column officer_id drop not null;

alter table public.report_audit_log
  drop constraint if exists report_audit_log_action_check;

alter table public.report_audit_log
  add constraint report_audit_log_action_check
  check (
    action in (
      'view',
      'update_status',
      'emergency_activated',
      'emergency_location_update',
      'emergency_stopped',
      'identity_revealed'
    )
  );

drop policy if exists "officers read own audit" on public.report_audit_log;
create policy "officers read own audit"
  on public.report_audit_log for select
  to authenticated
  using (
    officer_id = auth.uid()
    or exists (
      select 1 from public.reports r
       where r.id = report_audit_log.report_id
         and r.station_id = officer_station_id()
    )
  );

create or replace function public.log_emergency_report_events()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.is_emergency = true then
    insert into public.report_audit_log (officer_id, report_id, action)
    values (null, new.id, 'emergency_activated');

    insert into public.alert_outbox (station_id, channel, body)
    values (
      new.station_id,
      'email',
      'URGENT Kasat emergency alert — log in immediately.'
    );
  elsif tg_op = 'UPDATE' and new.is_emergency = true then
    if old.live_location_active = true and new.live_location_active = false then
      insert into public.report_audit_log (officer_id, report_id, action)
      values (null, new.id, 'emergency_stopped');
    elsif new.live_latitude is distinct from old.live_latitude
       or new.live_longitude is distinct from old.live_longitude then
      insert into public.report_audit_log (officer_id, report_id, action)
      values (null, new.id, 'emergency_location_update');
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists reports_emergency_audit on public.reports;
create trigger reports_emergency_audit
  after insert or update on public.reports
  for each row execute function public.log_emergency_report_events();

-- ---------------------------------------------------------------------------
-- 3. Separate one-way `report_identities` table (anonymous -> named)
-- ---------------------------------------------------------------------------

create table if not exists public.report_identities (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null unique references public.reports (id) on delete cascade,
  tracking_code text not null unique,
  full_name text not null check (char_length(btrim(full_name)) between 1 and 120),
  contact_channel text not null check (contact_channel in ('phone', 'email')),
  contact_handle text not null check (char_length(btrim(contact_handle)) between 3 and 160),
  safe_note text,
  revealed_at timestamptz not null default now()
);

create index if not exists report_identities_report_idx
  on public.report_identities (report_id);

alter table public.report_identities enable row level security;

-- One-way enforcement: nobody can update or delete an identity once revealed.
revoke all on public.report_identities from public, anon, authenticated;
grant select on public.report_identities to anon, authenticated;

create or replace function public.report_identities_immutable_guard()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Self-identification is one-way and cannot be undone or modified.';
end;
$$;

drop trigger if exists report_identities_no_update on public.report_identities;
create trigger report_identities_no_update
  before update or delete on public.report_identities
  for each row execute function public.report_identities_immutable_guard();

drop policy if exists "survivor read own revealed identity" on public.report_identities;
create policy "survivor read own revealed identity"
  on public.report_identities for select
  to anon
  using (
    tracking_code = current_setting('request.headers', true)::json ->> 'x-tracking-code'
  );

drop policy if exists "officers read station revealed identities" on public.report_identities;
create policy "officers read station revealed identities"
  on public.report_identities for select
  to authenticated
  using (
    exists (
      select 1 from public.reports r
       where r.id = report_identities.report_id
         and r.status <> 'draft'
         and r.station_id = officer_station_id()
    )
  );

create or replace function public.reveal_report_identity(
  p_tracking_code text,
  p_full_name text,
  p_contact_channel text,
  p_contact_handle text,
  p_safe_note text default null
)
returns public.report_identities
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report_id uuid;
  v_header_code text;
  v_row public.report_identities;
begin
  v_header_code := current_setting('request.headers', true)::json ->> 'x-tracking-code';
  if v_header_code is not null and v_header_code <> '' and v_header_code <> p_tracking_code then
    raise exception 'tracking code mismatch';
  end if;

  select r.id into v_report_id
    from public.reports r
   where r.tracking_code = p_tracking_code
   limit 1;

  if v_report_id is null then
    raise exception 'Report not found for tracking code %', p_tracking_code;
  end if;

  if exists (select 1 from public.report_identities ri where ri.report_id = v_report_id) then
    raise exception 'Identity has already been revealed for this report and cannot be changed.';
  end if;

  insert into public.report_identities (
    report_id,
    tracking_code,
    full_name,
    contact_channel,
    contact_handle,
    safe_note
  )
  values (
    v_report_id,
    p_tracking_code,
    btrim(p_full_name),
    p_contact_channel,
    btrim(p_contact_handle),
    nullif(btrim(coalesce(p_safe_note, '')), '')
  )
  returning * into v_row;

  perform set_config('kasat.allow_identity_flag', '1', true);
  update public.reports
     set identity_revealed = true
   where id = v_report_id;

  insert into public.report_audit_log (officer_id, report_id, action)
  values (null, v_report_id, 'identity_revealed');

  return v_row;
end;
$$;

revoke all on function public.reveal_report_identity(text, text, text, text, text) from public;
grant execute on function public.reveal_report_identity(text, text, text, text, text) to anon, authenticated;

alter table public.report_identities replica identity full;
do $$ begin
  alter publication supabase_realtime add table public.report_identities;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
