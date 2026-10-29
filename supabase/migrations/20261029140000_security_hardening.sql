-- Kasat production security hardening (audit C1–C7, H1–H6, M1–M5, L1–L2).
-- Does not rewrite or delete existing survivor rows (C6). Seed data belongs in
-- supabase/seed.sql and is local-only.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Internal pepper (generated on first apply, never in source)
-- ---------------------------------------------------------------------------
create table if not exists public.kasat_internal_secrets (
  key text primary key,
  value text not null
);
alter table public.kasat_internal_secrets enable row level security;
revoke all on table public.kasat_internal_secrets from public, anon, authenticated;

insert into public.kasat_internal_secrets (key, value)
values ('hmac_pepper', encode(extensions.gen_random_bytes(32), 'hex'))
on conflict (key) do nothing;

create or replace function public._kasat_hmac(p_payload text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pepper text;
begin
  if p_payload is null or btrim(p_payload) = '' then
    return null;
  end if;
  select s.value into v_pepper
    from public.kasat_internal_secrets s
   where s.key = 'hmac_pepper';
  if v_pepper is null then
    raise exception 'server pepper missing';
  end if;
  return encode(extensions.hmac(p_payload, v_pepper, 'sha256'), 'hex');
end;
$$;
revoke all on function public._kasat_hmac(text) from public, anon, authenticated;

create or replace function public._new_tracking_code()
returns text
language plpgsql
set search_path = ''
as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKMNPQRSTVWXYZ';
  code text;
  i int;
begin
  loop
    code := 'KST-';
    for i in 1..5 loop
      code := code || substr(alphabet, 1 + (floor(random() * 32))::int, 1);
    end loop;
    exit when not exists (
      select 1 from public.reports r where r.tracking_code = code
    );
  end loop;
  return code;
end;
$$;
revoke all on function public._new_tracking_code() from public, anon, authenticated;

create or replace function public._new_access_secret()
returns text
language sql
set search_path = ''
as $$
  select encode(extensions.gen_random_bytes(32), 'hex');
$$;
revoke all on function public._new_access_secret() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- C2 / H1: RLS on officer tables; revoke public writes
-- ---------------------------------------------------------------------------
alter table public.stations enable row level security;
alter table public.officers enable row level security;
alter table public.officer_teams enable row level security;

revoke all on table public.stations from public, anon, authenticated;
revoke all on table public.officers from public, anon, authenticated;
revoke all on table public.officer_teams from public, anon, authenticated;
grant select on table public.stations to authenticated;
grant select on table public.officers to authenticated;
grant select on table public.officer_teams to authenticated;

drop policy if exists "officers read stations" on public.stations;
create policy "officers read stations"
  on public.stations for select to authenticated
  using (id = public.officer_station_id());

drop policy if exists "officers read own roster" on public.officers;
create policy "officers read own roster"
  on public.officers for select to authenticated
  using (station_id = public.officer_station_id() or id = auth.uid());

drop policy if exists "officers read own teams" on public.officer_teams;
create policy "officers read own teams"
  on public.officer_teams for select to authenticated
  using (station_id = public.officer_station_id());

create or replace function public.officer_station_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(o.station_id, t.station_id)
    from public.officers o
    left join public.officer_teams t on t.id = o.team_id
   where o.id = auth.uid()
$$;
revoke all on function public.officer_station_id() from public, anon;
grant execute on function public.officer_station_id() to authenticated;

create or replace function public._require_officer()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  sid uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  sid := public.officer_station_id();
  if sid is null then
    raise exception 'not an officer';
  end if;
  return sid;
end;
$$;
revoke all on function public._require_officer() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- C4: high-entropy access secret; device secret hash for coalesce
-- ---------------------------------------------------------------------------
alter table public.reports
  add column if not exists access_secret text,
  add column if not exists device_secret_hash text;

update public.reports
   set access_secret = encode(extensions.gen_random_bytes(32), 'hex')
 where access_secret is null;

alter table public.reports
  alter column access_secret set default encode(extensions.gen_random_bytes(32), 'hex');

create unique index if not exists reports_access_secret_uidx
  on public.reports (access_secret);
create index if not exists reports_device_secret_hash_idx
  on public.reports (device_secret_hash, created_at desc);

-- ---------------------------------------------------------------------------
-- H3: append-only approach history; never null a real answer
-- ---------------------------------------------------------------------------
create table if not exists public.approach_response_history (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete cascade,
  response text not null,
  actor_role text not null check (actor_role in ('survivor', 'officer_timeout')),
  created_at timestamptz not null default now()
);
alter table public.approach_response_history enable row level security;
revoke all on table public.approach_response_history from public, anon, authenticated;
grant select on table public.approach_response_history to authenticated;

drop policy if exists "officers read approach history" on public.approach_response_history;
create policy "officers read approach history"
  on public.approach_response_history for select to authenticated
  using (
    exists (
      select 1 from public.reports r
       where r.id = approach_response_history.report_id
         and r.station_id = public.officer_station_id()
         and r.status <> 'draft'
    )
  );

-- ---------------------------------------------------------------------------
-- JSON projections (never return secrets/hashes/GPS to the wrong caller)
-- ---------------------------------------------------------------------------
create or replace function public._survivor_report_json(
  r public.reports,
  include_secret boolean
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'tracking_code', r.tracking_code,
    'access_secret', case when include_secret then r.access_secret else null end,
    'incident_type', r.incident_type,
    'approx_location', r.approx_location,
    'description', r.description,
    'photo_url', r.photo_url,
    'status', r.status,
    'dispatch_status', r.dispatch_status,
    'sent_at', r.sent_at,
    'created_at', r.created_at,
    'is_emergency', r.is_emergency,
    'silent_mode', r.silent_mode,
    'live_location_active', r.live_location_active,
    'activation_count', r.activation_count,
    'officer_arrived_at', r.officer_arrived_at,
    'approach_response_window_sec', r.approach_response_window_sec,
    'approach_response', r.approach_response,
    'approach_responded_at', r.approach_responded_at,
    'identity_revealed', r.identity_revealed,
    'evidence_sha256', r.evidence_sha256,
    'client_evidence_sha256', r.client_evidence_sha256,
    'evidence_verified_at', r.evidence_verified_at,
    'evidence_integrity_status', r.evidence_integrity_status
  );
$$;
revoke all on function public._survivor_report_json(public.reports, boolean) from public, anon, authenticated;

create or replace function public._officer_report_json(
  r public.reports,
  include_sensitive boolean
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', r.id,
    'tracking_code', r.tracking_code,
    'incident_type', r.incident_type,
    'approx_location', r.approx_location,
    'description', r.description,
    'photo_url', r.photo_url,
    'status', r.status,
    'dispatch_status', r.dispatch_status,
    'claimed_by_officer_id', r.claimed_by_officer_id,
    'claimed_by_name', r.claimed_by_name,
    'claimed_at', r.claimed_at,
    'en_route_at', r.en_route_at,
    'on_scene_at', r.on_scene_at,
    'resolved_at', r.resolved_at,
    'sla_status', r.sla_status,
    'sla_escalated_at', r.sla_escalated_at,
    'unanswered_marked_at', r.unanswered_marked_at,
    'rerouted_to', r.rerouted_to,
    'activation_count', r.activation_count,
    'sent_at', r.sent_at,
    'created_at', r.created_at,
    'is_emergency', r.is_emergency,
    'silent_mode', r.silent_mode,
    'live_location_active', r.live_location_active,
    'location_updated_at', case when include_sensitive then r.location_updated_at else null end,
    'live_latitude', case when include_sensitive then r.live_latitude else null end,
    'live_longitude', case when include_sensitive then r.live_longitude else null end,
    'live_accuracy_meters', case when include_sensitive then r.live_accuracy_meters else null end,
    'officer_arrived_at', r.officer_arrived_at,
    'approach_response_window_sec', r.approach_response_window_sec,
    'approach_response', r.approach_response,
    'approach_responded_at', r.approach_responded_at,
    'identity_revealed', r.identity_revealed,
    'evidence_sha256', r.evidence_sha256,
    'client_evidence_sha256', r.client_evidence_sha256,
    'evidence_verified_at', r.evidence_verified_at,
    'evidence_integrity_status', r.evidence_integrity_status
  );
$$;
revoke all on function public._officer_report_json(public.reports, boolean) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- H1: officer queue without GPS/identity; claim-gated sensitive RPC
-- ---------------------------------------------------------------------------
create or replace function public.list_station_reports()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  sid uuid := public._require_officer();
begin
  return coalesce((
    select jsonb_agg(public._officer_report_json(r, false) order by r.is_emergency desc, r.sent_at desc)
      from public.reports r
     where r.status <> 'draft'
       and r.station_id = sid
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.list_station_reports() from public, anon;
grant execute on function public.list_station_reports() to authenticated;

create or replace function public.get_report_sensitive(p_tracking_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sid uuid := public._require_officer();
  r public.reports;
  ident jsonb;
begin
  select * into r
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
     and station_id = sid
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;
  if r.claimed_by_officer_id is distinct from auth.uid() then
    raise exception 'claim required';
  end if;

  insert into public.report_audit_log (officer_id, report_id, action)
  values (auth.uid(), r.id, 'location_unlock');

  select to_jsonb(ri) into ident
    from public.report_identities ri
   where ri.report_id = r.id
   limit 1;

  return public._officer_report_json(r, true)
    || jsonb_build_object('report_identities', ident);
end;
$$;
revoke all on function public.get_report_sensitive(text) from public, anon;
grant execute on function public.get_report_sensitive(text) to authenticated;

-- ---------------------------------------------------------------------------
-- C4 / C5: survivor RPCs keyed by access_secret (never header-optional codes)
-- ---------------------------------------------------------------------------
create or replace function public.create_draft_report(
  p_incident_type text,
  p_description text,
  p_approx_location text default null,
  p_photo_url text default null,
  p_client_sha256 text default null,
  p_tracking_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  v_code text;
begin
  v_code := nullif(btrim(coalesce(p_tracking_code, '')), '');
  if v_code is null
     or v_code !~ '^KST-[23456789ABCDEFGHJKMNPQRSTVWXYZ]{5}$'
     or exists (select 1 from public.reports x where x.tracking_code = v_code) then
    v_code := public._new_tracking_code();
  end if;

  insert into public.reports (
    tracking_code,
    access_secret,
    incident_type,
    approx_location,
    description,
    photo_url,
    status,
    client_evidence_sha256,
    evidence_integrity_status
  )
  values (
    v_code,
    public._new_access_secret(),
    p_incident_type,
    nullif(btrim(coalesce(p_approx_location, '')), ''),
    p_description,
    nullif(btrim(coalesce(p_photo_url, '')), ''),
    'draft',
    nullif(lower(btrim(coalesce(p_client_sha256, ''))), ''),
    case when p_photo_url is not null and btrim(p_photo_url) <> '' then 'pending_server_hash' else 'none' end
  )
  returning * into r;

  return public._survivor_report_json(r, true);
end;
$$;
revoke all on function public.create_draft_report(text, text, text, text, text, text) from public;
grant execute on function public.create_draft_report(text, text, text, text, text, text) to anon, authenticated;

create or replace function public.send_draft_report(
  p_access_secret text,
  p_photo_url text default null,
  p_client_sha256 text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
begin
  select * into r
    from public.reports
   where access_secret = p_access_secret
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;
  if r.status not in ('draft', 'sent') then
    raise exception 'cannot send';
  end if;

  update public.reports
     set status = 'sent',
         sent_at = coalesce(sent_at, now()),
         photo_url = coalesce(nullif(btrim(coalesce(p_photo_url, '')), ''), photo_url),
         client_evidence_sha256 = coalesce(
           nullif(lower(btrim(coalesce(p_client_sha256, ''))), ''),
           client_evidence_sha256
         ),
         evidence_integrity_status = case
           when coalesce(nullif(btrim(coalesce(p_photo_url, '')), ''), photo_url) is not null
                and evidence_sha256 is null
             then 'pending_server_hash'
           else evidence_integrity_status
         end
   where id = r.id
   returning * into r;

  return public._survivor_report_json(r, true);
end;
$$;
revoke all on function public.send_draft_report(text, text, text) from public;
grant execute on function public.send_draft_report(text, text, text) to anon, authenticated;

create or replace function public.lookup_own_report(p_access_secret text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r public.reports;
begin
  select * into r from public.reports where access_secret = p_access_secret limit 1;
  if r.id is null then
    return null;
  end if;
  return public._survivor_report_json(r, true);
end;
$$;
revoke all on function public.lookup_own_report(text) from public;
grant execute on function public.lookup_own_report(text) to anon, authenticated;

create or replace function public.update_emergency_location(
  p_access_secret text,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_meters double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
begin
  select * into r
    from public.reports
   where access_secret = p_access_secret
     and is_emergency = true
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;

  update public.reports
     set live_latitude = p_latitude,
         live_longitude = p_longitude,
         live_accuracy_meters = coalesce(p_accuracy_meters, live_accuracy_meters),
         location_updated_at = now(),
         live_location_active = true
   where id = r.id
   returning * into r;

  return public._survivor_report_json(r, false);
end;
$$;
revoke all on function public.update_emergency_location(text, double precision, double precision, double precision) from public;
grant execute on function public.update_emergency_location(text, double precision, double precision, double precision) to anon, authenticated;

create or replace function public.stop_emergency_location(p_access_secret text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
begin
  select * into r
    from public.reports
   where access_secret = p_access_secret
     and is_emergency = true
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;

  update public.reports
     set live_location_active = false
   where id = r.id
   returning * into r;

  return public._survivor_report_json(r, false);
end;
$$;
revoke all on function public.stop_emergency_location(text) from public;
grant execute on function public.stop_emergency_location(text) to anon, authenticated;

drop function if exists public.submit_approach_response(text, text);
create or replace function public.submit_approach_response(
  p_access_secret text,
  p_response text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  v_audit text;
begin
  if p_response not in ('can_come_out', 'abuser_present_do_not_knock') then
    raise exception 'Invalid approach_response %', p_response;
  end if;

  select * into r from public.reports where access_secret = p_access_secret limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;

  insert into public.approach_response_history (report_id, response, actor_role)
  values (r.id, p_response, 'survivor');

  update public.reports
     set approach_response = p_response,
         approach_responded_at = now()
   where id = r.id
   returning * into r;

  v_audit := case
    when p_response = 'can_come_out' then 'approach_response_can_come_out'
    else 'approach_response_do_not_knock'
  end;
  insert into public.report_audit_log (officer_id, report_id, action)
  values (null, r.id, v_audit);

  return public._survivor_report_json(r, false);
end;
$$;
revoke all on function public.submit_approach_response(text, text) from public;
grant execute on function public.submit_approach_response(text, text) to anon, authenticated;

drop function if exists public.reveal_report_identity(text, text, text, text, text);
create or replace function public.reveal_report_identity(
  p_access_secret text,
  p_full_name text,
  p_contact_channel text,
  p_contact_handle text,
  p_safe_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  v_row public.report_identities;
begin
  select * into r from public.reports where access_secret = p_access_secret limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;
  if exists (select 1 from public.report_identities ri where ri.report_id = r.id) then
    raise exception 'Identity has already been revealed for this report and cannot be changed.';
  end if;

  insert into public.report_identities (
    report_id, tracking_code, full_name, contact_channel, contact_handle, safe_note
  )
  values (
    r.id,
    r.tracking_code,
    btrim(p_full_name),
    p_contact_channel,
    btrim(p_contact_handle),
    nullif(btrim(coalesce(p_safe_note, '')), '')
  )
  returning * into v_row;

  update public.reports set identity_revealed = true where id = r.id;

  insert into public.report_audit_log (officer_id, report_id, action)
  values (null, r.id, 'identity_revealed');

  return jsonb_build_object('ok', true, 'tracking_code', r.tracking_code);
end;
$$;
revoke all on function public.reveal_report_identity(text, text, text, text, text) from public;
grant execute on function public.reveal_report_identity(text, text, text, text, text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- C3 / H2 / H4: coalesce only on device secret; no location/IP matching
-- ---------------------------------------------------------------------------
drop function if exists public.trigger_or_coalesce_emergency(text, text, text, boolean, double precision, double precision, double precision, text);

create or replace function public.trigger_or_coalesce_emergency(
  p_description text,
  p_approx_location text default null,
  p_silent_mode boolean default false,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_accuracy_meters double precision default null,
  p_device_secret text default null,
  p_tracking_code text default null,
  p_access_secret text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dev_hash text;
  r public.reports;
  v_device_count integer;
  v_approx text := coalesce(nullif(btrim(p_approx_location), ''), 'Bole — Near Edna Mall');
  v_code text;
begin
  if p_device_secret is null or btrim(p_device_secret) = '' then
    raise exception 'device secret required';
  end if;
  if char_length(btrim(p_device_secret)) < 32 then
    raise exception 'device secret required';
  end if;

  v_dev_hash := public._kasat_hmac('device:' || btrim(p_device_secret));

  if p_access_secret is not null and btrim(p_access_secret) <> '' then
    select * into r
      from public.reports
     where access_secret = p_access_secret
       and is_emergency = true
     limit 1;
  end if;

  if r.id is null then
    select * into r
      from public.reports
     where is_emergency = true
       and dispatch_status <> 'resolved'
       and status <> 'resolved'
       and device_secret_hash = v_dev_hash
       and created_at >= now() - interval '15 minutes'
     order by created_at desc
     limit 1;
  end if;

  if r.id is not null then
    update public.reports
       set live_latitude = coalesce(p_latitude, live_latitude),
           live_longitude = coalesce(p_longitude, live_longitude),
           live_accuracy_meters = coalesce(p_accuracy_meters, live_accuracy_meters),
           location_updated_at = now(),
           live_location_active = true,
           silent_mode = (silent_mode or coalesce(p_silent_mode, false)),
           activation_count = coalesce(activation_count, 1) + 1
     where id = r.id
       and device_secret_hash = v_dev_hash
     returning * into r;

    if r.id is null then
      raise exception 'not found';
    end if;

    insert into public.emergency_rate_limit_events (device_hash, event_type, target_report_id)
    values (v_dev_hash, 'coalesced', r.id);
    insert into public.report_audit_log (officer_id, report_id, action)
    values (null, r.id, 'emergency_coalesced_heartbeat');

    return public._survivor_report_json(r, true);
  end if;

  select count(*) into v_device_count
    from public.reports x
   where x.is_emergency = true
     and x.device_secret_hash = v_dev_hash
     and x.created_at >= now() - interval '30 minutes';
  if v_device_count >= 3 then
    insert into public.emergency_rate_limit_events (device_hash, event_type)
    values (v_dev_hash, 'rejected_device_cap');
    raise exception 'rate_limit_exceeded: maximum emergency activations per device window reached';
  end if;

  v_code := nullif(btrim(coalesce(p_tracking_code, '')), '');
  if v_code is null
     or v_code !~ '^KST-[23456789ABCDEFGHJKMNPQRSTVWXYZ]{5}$'
     or exists (select 1 from public.reports x where x.tracking_code = v_code) then
    v_code := public._new_tracking_code();
  end if;

  insert into public.reports (
    tracking_code,
    access_secret,
    incident_type,
    approx_location,
    description,
    status,
    dispatch_status,
    sent_at,
    is_emergency,
    silent_mode,
    live_latitude,
    live_longitude,
    live_accuracy_meters,
    location_updated_at,
    live_location_active,
    activation_count,
    device_secret_hash
  )
  values (
    v_code,
    public._new_access_secret(),
    'CRTCL',
    v_approx,
    p_description,
    'sent',
    'new',
    now(),
    true,
    coalesce(p_silent_mode, false),
    p_latitude,
    p_longitude,
    p_accuracy_meters,
    case when p_latitude is not null then now() else null end,
    true,
    1,
    v_dev_hash
  )
  returning * into r;

  return public._survivor_report_json(r, true);
end;
$$;
revoke all on function public.trigger_or_coalesce_emergency(text, text, boolean, double precision, double precision, double precision, text, text, text) from public, anon, authenticated;
grant execute on function public.trigger_or_coalesce_emergency(text, text, boolean, double precision, double precision, double precision, text, text, text) to service_role;

create or replace function public.check_emergency_ip_limit(p_ip text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hash text;
  v_count integer;
begin
  if p_ip is null or btrim(p_ip) = '' then
    return;
  end if;
  v_hash := public._kasat_hmac('ip:' || btrim(p_ip));
  select count(*) into v_count
    from public.emergency_rate_limit_events e
   where e.ip_hash = v_hash
     and e.created_at >= now() - interval '10 minutes';
  if v_count >= 10 then
    insert into public.emergency_rate_limit_events (ip_hash, event_type)
    values (v_hash, 'rejected_ip_cap');
    raise exception 'rate_limit_exceeded: maximum emergency activations per IP window reached';
  end if;
  insert into public.emergency_rate_limit_events (ip_hash, event_type)
  values (v_hash, 'coalesced');
end;
$$;
revoke all on function public.check_emergency_ip_limit(text) from public, anon, authenticated;
grant execute on function public.check_emergency_ip_limit(text) to service_role;

-- ---------------------------------------------------------------------------
-- L2: revoke fingerprint helper; stop using public salt
-- ---------------------------------------------------------------------------
revoke all on function public.compute_request_fingerprints(double precision, double precision) from public, anon, authenticated;

create or replace function public.compute_request_fingerprints(
  p_lat double precision,
  p_lon double precision,
  out o_device_hash text,
  out o_ip_hash text,
  out o_coord_cell text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  o_device_hash := null;
  o_ip_hash := null;
  o_coord_cell := null;
end;
$$;
revoke all on function public.compute_request_fingerprints(double precision, double precision) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- C7: evidence hash must not rewrite photo_url
-- ---------------------------------------------------------------------------
create or replace function public.record_server_evidence_hash(
  p_tracking_code text,
  p_photo_url text,
  p_server_sha256 text,
  p_client_sha256 text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  v_server_hash text := lower(btrim(p_server_sha256));
  v_client_hash text;
  v_status text;
  v_now timestamptz := now();
  v_key text;
begin
  if v_server_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid server sha256 digest';
  end if;
  v_key := btrim(coalesce(p_photo_url, ''));
  if v_key = '' or position('..' in v_key) > 0 then
    raise exception 'invalid object key';
  end if;
  if v_key !~ '^KST-[23456789ABCDEFGHJKMNPQRSTVWXYZ]{5}/[0-9a-fA-F-]{36}\.(png|jpe?g|webp)$' then
    raise exception 'invalid object key';
  end if;
  if split_part(v_key, '/', 1) is distinct from p_tracking_code then
    raise exception 'object key does not match tracking code';
  end if;

  select * into r from public.reports where tracking_code = p_tracking_code limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;
  if r.photo_url is distinct from v_key then
    raise exception 'object key does not match stored evidence';
  end if;

  v_client_hash := lower(btrim(coalesce(p_client_sha256, r.client_evidence_sha256, '')));
  if v_client_hash = '' then
    v_client_hash := null;
    v_status := 'verified';
  elsif v_client_hash = v_server_hash then
    v_status := 'verified';
  else
    v_status := 'mismatch';
  end if;

  update public.reports
     set evidence_sha256 = v_server_hash,
         client_evidence_sha256 = coalesce(v_client_hash, client_evidence_sha256),
         evidence_verified_at = v_now,
         evidence_integrity_status = v_status
   where id = r.id
   returning * into r;

  insert into public.report_audit_log (officer_id, report_id, action)
  values (
    null,
    r.id,
    case when v_status = 'verified' then 'evidence_hashed' else 'evidence_hash_mismatch' end
  );

  return jsonb_build_object(
    'tracking_code', r.tracking_code,
    'server_sha256', r.evidence_sha256,
    'client_sha256', r.client_evidence_sha256,
    'integrity_status', r.evidence_integrity_status,
    'verified_at', r.evidence_verified_at,
    'transport_match', (v_status = 'verified')
  );
end;
$$;
revoke all on function public.record_server_evidence_hash(text, text, text, text) from public, anon, authenticated;
grant execute on function public.record_server_evidence_hash(text, text, text, text) to service_role;

create or replace function public.prepare_evidence_object(
  p_access_secret text,
  p_object_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  v_key text := btrim(coalesce(p_object_key, ''));
begin
  select * into r from public.reports where access_secret = p_access_secret limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;
  if position('..' in v_key) > 0
     or v_key !~ ('^' || r.tracking_code || '/[0-9a-fA-F-]{36}\.(png|jpe?g|webp)$') then
    raise exception 'invalid object key';
  end if;

  update public.reports
     set photo_url = v_key,
         evidence_integrity_status = 'pending_server_hash'
   where id = r.id;

  return jsonb_build_object('tracking_code', r.tracking_code, 'object_key', v_key);
end;
$$;
revoke all on function public.prepare_evidence_object(text, text) from public, anon, authenticated;
grant execute on function public.prepare_evidence_object(text, text) to service_role;

-- ---------------------------------------------------------------------------
-- M3 / M4: claim lock; officer name from officers row; H3 keep approach_response
-- ---------------------------------------------------------------------------
create or replace function public.transition_report_dispatch(
  p_tracking_code text,
  p_next_status text,
  p_officer_name text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sid uuid := public._require_officer();
  r public.reports;
  v_officer_name text;
  v_mapped public.report_status;
  v_audit text;
  v_sensitive boolean;
begin
  if p_next_status not in ('claimed', 'en_route', 'on_scene', 'resolved') then
    raise exception 'Invalid dispatch_status transition target: %', p_next_status;
  end if;

  select * into r
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
     and station_id = sid
   for update;
  if r.id is null then
    raise exception 'Report % not found in station queue', p_tracking_code;
  end if;

  if r.dispatch_status = 'new' and p_next_status <> 'claimed' then
    raise exception 'Unclaimed alert must be claimed first';
  end if;
  if r.dispatch_status <> 'new'
     and r.claimed_by_officer_id is distinct from auth.uid() then
    raise exception 'not claimant';
  end if;

  select o.name into v_officer_name from public.officers o where o.id = auth.uid();
  v_officer_name := coalesce(v_officer_name, 'Station Officer');

  v_mapped := case
    when p_next_status = 'resolved' then 'resolved'::public.report_status
    else 'under_review'::public.report_status
  end;
  v_audit := case p_next_status
    when 'claimed' then 'dispatch_claimed'
    when 'en_route' then 'dispatch_en_route'
    when 'on_scene' then 'dispatch_on_scene'
    when 'resolved' then 'dispatch_resolved'
  end;

  update public.reports
     set dispatch_status = p_next_status,
         status = v_mapped,
         claimed_by_officer_id = coalesce(claimed_by_officer_id, auth.uid()),
         claimed_by_name = coalesce(claimed_by_name, v_officer_name),
         claimed_at = coalesce(claimed_at, now()),
         en_route_at = case
           when p_next_status in ('en_route', 'on_scene', 'resolved') then coalesce(en_route_at, now())
           else en_route_at
         end,
         on_scene_at = case
           when p_next_status in ('on_scene', 'resolved') then coalesce(on_scene_at, now())
           else on_scene_at
         end,
         resolved_at = case
           when p_next_status = 'resolved' then coalesce(resolved_at, now())
           else resolved_at
         end,
         sla_status = case
           when p_next_status = 'resolved' then 'ok'
           when sla_status in ('claim_breached', 'unanswered')
                and p_next_status in ('claimed', 'en_route', 'on_scene') then 'ok'
           else sla_status
         end
   where id = r.id
   returning * into r;

  insert into public.report_audit_log (officer_id, report_id, action)
  values (auth.uid(), r.id, v_audit);
  if p_next_status = 'claimed' then
    insert into public.report_audit_log (officer_id, report_id, action)
    values (auth.uid(), r.id, 'location_unlock');
  end if;

  v_sensitive := r.claimed_by_officer_id = auth.uid();
  return public._officer_report_json(r, v_sensitive);
end;
$$;
revoke all on function public.transition_report_dispatch(text, text, text, text) from public, anon;
grant execute on function public.transition_report_dispatch(text, text, text, text) to authenticated;

create or replace function public.signal_officer_arrived(
  p_tracking_code text,
  p_window_sec integer default 90
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sid uuid := public._require_officer();
  r public.reports;
  v_window integer := greatest(15, least(coalesce(p_window_sec, 90), 600));
  v_officer_name text;
begin
  select * into r
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
     and station_id = sid
   for update;
  if r.id is null then
    raise exception 'Emergency report % not found in your station queue', p_tracking_code;
  end if;
  if r.claimed_by_officer_id is distinct from auth.uid()
     and r.dispatch_status <> 'new' then
    raise exception 'not claimant';
  end if;

  select o.name into v_officer_name from public.officers o where o.id = auth.uid();

  update public.reports
     set officer_arrived_at = now(),
         officer_arrived_by = auth.uid(),
         approach_response_window_sec = v_window,
         status = case when status = 'sent' then 'under_review' else status end,
         dispatch_status = case when dispatch_status = 'resolved' then 'resolved' else 'on_scene' end,
         claimed_by_officer_id = coalesce(claimed_by_officer_id, auth.uid()),
         claimed_by_name = coalesce(claimed_by_name, v_officer_name, 'Station Officer'),
         claimed_at = coalesce(claimed_at, now()),
         en_route_at = coalesce(en_route_at, now()),
         on_scene_at = coalesce(on_scene_at, now())
   where id = r.id
   returning * into r;

  insert into public.report_audit_log (officer_id, report_id, action)
  values (auth.uid(), r.id, 'officer_arrived');

  return public._officer_report_json(r, r.claimed_by_officer_id = auth.uid());
end;
$$;
revoke all on function public.signal_officer_arrived(text, integer) from public, anon;
grant execute on function public.signal_officer_arrived(text, integer) to authenticated;

create or replace function public.log_approach_no_response(p_tracking_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sid uuid := public._require_officer();
  r public.reports;
begin
  select * into r
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
     and station_id = sid
   limit 1;
  if r.id is null then
    raise exception 'Report % not found', p_tracking_code;
  end if;
  if r.claimed_by_officer_id is distinct from auth.uid() then
    raise exception 'not claimant';
  end if;
  if r.approach_response in ('can_come_out', 'abuser_present_do_not_knock') then
    return public._officer_report_json(r, true);
  end if;

  insert into public.approach_response_history (report_id, response, actor_role)
  values (r.id, 'no_response', 'officer_timeout');

  update public.reports
     set approach_response = 'no_response',
         approach_responded_at = coalesce(approach_responded_at, now())
   where id = r.id
     and approach_response is distinct from 'can_come_out'
     and approach_response is distinct from 'abuser_present_do_not_knock'
   returning * into r;

  if not exists (
    select 1 from public.report_audit_log a
     where a.report_id = r.id
       and a.action = 'approach_no_response'
       and a.created_at >= coalesce(r.officer_arrived_at, now() - interval '10 minutes')
  ) then
    insert into public.report_audit_log (officer_id, report_id, action)
    values (auth.uid(), r.id, 'approach_no_response');
  end if;

  return public._officer_report_json(r, true);
end;
$$;
revoke all on function public.log_approach_no_response(text) from public, anon;
grant execute on function public.log_approach_no_response(text) to authenticated;

create or replace function public.record_sla_escalation(
  p_tracking_code text,
  p_sla_status text,
  p_reroute_target text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sid uuid := public._require_officer();
  r public.reports;
  v_audit text;
begin
  if p_sla_status not in ('claim_breached', 'on_scene_breached', 'unanswered', 'rerouted') then
    raise exception 'Invalid sla_status: %', p_sla_status;
  end if;

  select * into r
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
     and station_id = sid
   limit 1;
  if r.id is null then
    raise exception 'Report % not found', p_tracking_code;
  end if;

  update public.reports
     set sla_status = p_sla_status,
         sla_escalated_at = coalesce(sla_escalated_at, now()),
         unanswered_marked_at = case
           when p_sla_status in ('unanswered', 'rerouted') then coalesce(unanswered_marked_at, now())
           else unanswered_marked_at
         end,
         rerouted_to = coalesce(nullif(btrim(p_reroute_target), ''), rerouted_to)
   where id = r.id
   returning * into r;

  v_audit := case p_sla_status
    when 'unanswered' then 'sla_marked_unanswered'
    when 'rerouted' then 'station_rerouted'
    else 'sla_breach_escalated'
  end;
  insert into public.report_audit_log (officer_id, report_id, action)
  values (auth.uid(), r.id, v_audit);

  return public._officer_report_json(r, r.claimed_by_officer_id = auth.uid());
end;
$$;
revoke all on function public.record_sla_escalation(text, text, text) from public, anon;
grant execute on function public.record_sla_escalation(text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Officer profile RPCs (station_id on officers, not team-only)
-- ---------------------------------------------------------------------------
create or replace function public.current_officer_profile()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
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
    from public.officers o
    left join public.officer_teams t on t.id = o.team_id
    join public.stations s on s.id = coalesce(o.station_id, t.station_id)
    join auth.users au on au.id = o.id
   where o.id = auth.uid();
  if result is null then
    raise exception 'not an officer';
  end if;
  return result;
end;
$$;
revoke all on function public.current_officer_profile() from public, anon;
grant execute on function public.current_officer_profile() to authenticated;

create or replace function public.list_teammates()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', o.id,
           'name', o.name,
           'badgeId', o.badge_id
         ) order by o.name), '[]'::jsonb)
    from public.officers o
   where o.station_id = public.officer_station_id()
     or o.team_id = (select x.team_id from public.officers x where x.id = auth.uid());
$$;
revoke all on function public.list_teammates() from public, anon;
grant execute on function public.list_teammates() to authenticated;

-- ---------------------------------------------------------------------------
-- Always assign station server-side (H4); ignore client station_id
-- ---------------------------------------------------------------------------
create or replace function public.reports_assign_station()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.station_id := null;
  select s.id into new.station_id
    from public.stations s
   where coalesce(s.country_code, 'ET') = 'ET'
   order by s.created_at
   limit 1;
  return new;
end;
$$;

create or replace function public.reports_write_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.claimed_by_officer_id := null;
    new.claimed_by_name := null;
    new.claimed_at := null;
    new.identity_revealed := false;
    new.officer_arrived_at := null;
    new.officer_arrived_by := null;
    new.access_secret := coalesce(new.access_secret, public._new_access_secret());
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- C4 / H1 / H2: revoke direct table access; column grants for officers
-- ---------------------------------------------------------------------------
drop policy if exists "survivor insert draft" on public.reports;
drop policy if exists "survivor lookup by tracking code" on public.reports;
drop policy if exists "survivor send by tracking code" on public.reports;
drop policy if exists "officers update status only" on public.reports;

revoke all on table public.reports from public, anon, authenticated;
grant select (
  id, tracking_code, incident_type, approx_location, description, photo_url,
  status, dispatch_status, claimed_by_officer_id, claimed_by_name, claimed_at,
  en_route_at, on_scene_at, resolved_at, sla_status, sla_escalated_at,
  unanswered_marked_at, rerouted_to, activation_count, sent_at, created_at,
  station_id, is_emergency, silent_mode, live_location_active,
  officer_arrived_at, approach_response_window_sec, approach_response,
  approach_responded_at, identity_revealed, evidence_sha256,
  client_evidence_sha256, evidence_verified_at, evidence_integrity_status
) on table public.reports to authenticated;

drop policy if exists "officers read sent reports" on public.reports;
create policy "officers read sent reports"
  on public.reports for select to authenticated
  using (status <> 'draft' and station_id = public.officer_station_id());

revoke all on table public.report_identities from public, anon, authenticated;
drop policy if exists "survivor read own revealed identity" on public.report_identities;
drop policy if exists "officers read station revealed identities" on public.report_identities;

drop policy if exists "officers read rate limit events" on public.emergency_rate_limit_events;
revoke all on table public.emergency_rate_limit_events from public, anon, authenticated;

drop policy if exists "officers read own audit" on public.report_audit_log;
drop policy if exists "officers read station audit" on public.report_audit_log;
create policy "officers read station audit"
  on public.report_audit_log for select to authenticated
  using (
    exists (
      select 1 from public.reports r
       where r.id = report_audit_log.report_id
         and r.station_id = public.officer_station_id()
    )
  );
grant select on table public.report_audit_log to authenticated;

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
      'identity_revealed',
      'evidence_hashed',
      'evidence_hash_mismatch',
      'officer_arrived',
      'approach_response_can_come_out',
      'approach_response_do_not_knock',
      'approach_no_response',
      'dispatch_claimed',
      'dispatch_en_route',
      'dispatch_on_scene',
      'dispatch_resolved',
      'sla_breach_escalated',
      'sla_marked_unanswered',
      'station_rerouted',
      'emergency_coalesced_heartbeat',
      'emergency_rate_limited',
      'location_unlock'
    )
  );

-- ---------------------------------------------------------------------------
-- M1 / M2: storage path, MIME, size, station-scoped officer reads
-- ---------------------------------------------------------------------------
update storage.buckets
   set file_size_limit = 5242880,
       allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp']
 where id in ('report-photos', 'incident-evidence');

drop policy if exists "anonymous report photo upload" on storage.objects;
drop policy if exists "officers read report photos" on storage.objects;
drop policy if exists "anonymous evidence upload" on storage.objects;
drop policy if exists "operators read evidence" on storage.objects;

create policy "officers read own station report photos"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'report-photos'
    and position('..' in name) = 0
    and exists (
      select 1 from public.reports r
       where r.tracking_code = split_part(name, '/', 1)
         and r.station_id = public.officer_station_id()
         and r.status <> 'draft'
    )
  );

do $$
begin
  if exists (select 1 from storage.buckets where id = 'incident-evidence') then
    execute $p$
      create policy "officers read own station incident evidence"
        on storage.objects for select to authenticated
        using (
          bucket_id = 'incident-evidence'
          and position('..' in name) = 0
          and exists (
            select 1 from public.reports r
             where r.tracking_code = split_part(name, '/', 1)
               and r.station_id = public.officer_station_id()
               and r.status <> 'draft'
          )
        )
    $p$;
  end if;
exception when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- H1 realtime: do not broadcast GPS. Safe event table instead.
-- ---------------------------------------------------------------------------
create table if not exists public.report_queue_events (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null,
  station_id uuid,
  tracking_code text not null,
  status text,
  dispatch_status text,
  is_emergency boolean,
  silent_mode boolean,
  identity_revealed boolean,
  updated_at timestamptz not null default now()
);
alter table public.report_queue_events enable row level security;
revoke all on table public.report_queue_events from public, anon, authenticated;
grant select on table public.report_queue_events to authenticated;
drop policy if exists "officers read station queue events" on public.report_queue_events;
create policy "officers read station queue events"
  on public.report_queue_events for select to authenticated
  using (station_id = public.officer_station_id());

create or replace function public.enqueue_report_queue_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'draft' then
    return new;
  end if;
  insert into public.report_queue_events (
    report_id, station_id, tracking_code, status, dispatch_status,
    is_emergency, silent_mode, identity_revealed
  )
  values (
    new.id, new.station_id, new.tracking_code, new.status::text,
    new.dispatch_status, new.is_emergency, new.silent_mode, new.identity_revealed
  );
  return new;
end;
$$;

drop trigger if exists reports_queue_events on public.reports;
create trigger reports_queue_events
  after insert or update on public.reports
  for each row execute function public.enqueue_report_queue_event();

do $$ begin
  alter publication supabase_realtime drop table public.reports;
exception when others then null;
end $$;
do $$ begin
  alter publication supabase_realtime drop table public.report_identities;
exception when others then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table public.report_queue_events;
exception when others then null;
end $$;
alter table public.report_queue_events replica identity full;

-- ---------------------------------------------------------------------------
-- M5: tighten incidents (if present)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from information_schema.tables
     where table_schema = 'public' and table_name = 'incidents'
  ) then
    execute 'drop policy if exists "anonymous submission" on public.incidents';
    execute $p$
      create policy "anonymous submission"
        on public.incidents for insert to anon
        with check (
          status::text = 'RECEIVED'
          and assigned_station is null
        )
    $p$;
  end if;
end $$;

notify pgrst, 'reload schema';
