-- Police Portal Dispatch Lifecycle, SLA & Auto-Escalation, Rate Limiting, and Addis Ababa Seed Fix
--
-- 1. Alert Lifecycle State Machine:
--      new -> claimed -> en_route -> on_scene -> resolved
--    Every transition records officer_id, officer_name, timestamp, and writes to `report_audit_log`.
-- 2. Response SLA & Auto-Escalation:
--    Tracks `sla_claim_breached_at`, `sla_unanswered_at`, `rerouted_to_station`, and exposes RPCs
--    to mark/escalate unanswered alerts and reroute to central dispatch / alternate sub-city.
-- 3. Rate Limiting & Active-Alert Coalescing:
--    Prevents duplicate emergency alert spam from one coordinate/device/IP while never blocking
--    a genuine repeat activation (coalesces repeat activations within 15 minutes into the active
--    emergency row and increments `activation_count`; enforces per-device and per-IP flood caps).
-- 4. Reseeds existing San Francisco simulator rows (37.78583, -122.40642) and `LIVE GPS:` labels
--    with realistic Addis Ababa sub-cities, landmarks, and coordinates.

-- ---------------------------------------------------------------------------
-- 1. Columns for Dispatch Lifecycle, SLA, and Rate-Limiting Coalescing
-- ---------------------------------------------------------------------------

alter table public.reports
  add column if not exists dispatch_status text not null default 'new'
    check (dispatch_status in ('new', 'claimed', 'en_route', 'on_scene', 'resolved')),
  add column if not exists claimed_by_officer_id uuid references auth.users (id) on delete set null,
  add column if not exists claimed_by_name text,
  add column if not exists claimed_at timestamptz,
  add column if not exists en_route_at timestamptz,
  add column if not exists on_scene_at timestamptz,
  add column if not exists resolved_at timestamptz,
  add column if not exists sla_status text not null default 'ok'
    check (sla_status in ('ok', 'claim_breached', 'on_scene_breached', 'unanswered', 'rerouted')),
  add column if not exists sla_escalated_at timestamptz,
  add column if not exists unanswered_marked_at timestamptz,
  add column if not exists rerouted_to text,
  add column if not exists activation_count integer not null default 1,
  add column if not exists device_hash text,
  add column if not exists ip_hash text,
  add column if not exists coord_cell text;

create index if not exists reports_dispatch_status_idx
  on public.reports (station_id, is_emergency desc, dispatch_status, sent_at desc);

create index if not exists reports_rate_limit_lookup_idx
  on public.reports (is_emergency, created_at desc, device_hash, ip_hash, coord_cell);

-- Backfill `dispatch_status` from existing `status` so legacy rows are consistent
update public.reports
   set dispatch_status = case
     when status = 'resolved' then 'resolved'
     when officer_arrived_at is not null then 'on_scene'
     when status = 'under_review' then 'claimed'
     else 'new'
   end,
   on_scene_at = coalesce(on_scene_at, officer_arrived_at),
   claimed_at = case
     when status in ('under_review', 'resolved') and claimed_at is null
       then coalesce(officer_arrived_at, sent_at, created_at)
     else claimed_at
   end,
   resolved_at = case
     when status = 'resolved' and resolved_at is null
       then coalesce(sent_at, created_at)
     else resolved_at
   end;

-- ---------------------------------------------------------------------------
-- 2. Extend `report_audit_log` check constraint for all lifecycle & SLA events
-- ---------------------------------------------------------------------------

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
      'emergency_rate_limited'
    )
  );

-- ---------------------------------------------------------------------------
-- 3. Rate-Limiting & Coalescing Infrastructure
-- ---------------------------------------------------------------------------

create table if not exists public.emergency_rate_limit_events (
  id uuid primary key default gen_random_uuid(),
  device_hash text,
  ip_hash text,
  coord_cell text,
  event_type text not null check (event_type in ('coalesced', 'rejected_device_cap', 'rejected_ip_cap')),
  target_report_id uuid references public.reports (id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.emergency_rate_limit_events enable row level security;
revoke all on public.emergency_rate_limit_events from public, anon;
grant select on public.emergency_rate_limit_events to authenticated;

drop policy if exists "officers read rate limit events" on public.emergency_rate_limit_events;
create policy "officers read rate limit events"
  on public.emergency_rate_limit_events for select
  to authenticated
  using (officer_station_id() is not null);

-- Helper to extract one-way salted SHA-256 hashes from PostgREST request headers
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
set search_path = public
as $$
declare
  v_headers json;
  v_raw_device text;
  v_raw_ip text;
  v_salt text := 'kasat-et-rate-limit-salt-v1';
begin
  begin
    v_headers := current_setting('request.headers', true)::json;
  exception when others then
    v_headers := '{}'::json;
  end;

  v_raw_device := nullif(btrim(coalesce(v_headers ->> 'x-kasat-device-hash', '')), '');
  v_raw_ip := nullif(
    btrim(
      split_part(
        coalesce(
          v_headers ->> 'x-forwarded-for',
          v_headers ->> 'cf-connecting-ip',
          v_headers ->> 'x-real-ip',
          ''
        ),
        ',',
        1
      )
    ),
    ''
  );

  if v_raw_device is not null then
    o_device_hash := encode(digest(v_salt || ':dev:' || v_raw_device, 'sha256'), 'hex');
  else
    o_device_hash := null;
  end if;

  if v_raw_ip is not null then
    o_ip_hash := encode(digest(v_salt || ':ip:' || v_raw_ip, 'sha256'), 'hex');
  else
    o_ip_hash := null;
  end if;

  if p_lat is not null and p_lon is not null then
    -- ~110m grid cell for coalescing identical-coordinate bursts
    o_coord_cell := round(p_lat::numeric, 3)::text || ',' || round(p_lon::numeric, 3)::text;
  else
    o_coord_cell := null;
  end if;
end;
$$;

-- RPC for survivor handset to trigger or coalesce an emergency alert safely.
-- If an active emergency from the same device (or same IP + ~100m coordinate cell)
-- was already triggered in the last 15 minutes and is not yet resolved, this
-- updates the existing row's GPS fix and increments `activation_count` instead of
-- creating duplicate cards in the police dispatch queue.
create or replace function public.trigger_or_coalesce_emergency(
  p_tracking_code text,
  p_approx_location text,
  p_description text,
  p_silent_mode boolean default false,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_accuracy_meters double precision default null,
  p_device_token text default null
)
returns public.reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fp record;
  v_dev_hash text;
  v_existing public.reports;
  v_device_count integer;
  v_ip_cell_count integer;
  v_ip_total_count integer;
  v_lat double precision := p_latitude;
  v_lon double precision := p_longitude;
  v_approx text := coalesce(nullif(btrim(p_approx_location), ''), 'Bole — Near Edna Mall');
  v_inserted public.reports;
begin
  -- Sanitize out-of-Ethiopia simulator coordinates (e.g., Apple Simulator default 37.78583, -122.40642)
  if v_lat is not null and v_lon is not null then
    if v_lat < 3.0 or v_lat > 15.5 or v_lon < 33.0 or v_lon > 48.5 then
      v_lat := 8.9979;
      v_lon := 38.7868;
    end if;
  end if;

  if v_approx like 'LIVE GPS:%' then
    v_approx := 'Bole — Near Edna Mall';
  end if;

  select * into v_fp from public.compute_request_fingerprints(v_lat, v_lon);

  if p_device_token is not null and btrim(p_device_token) <> '' then
    v_dev_hash := encode(digest('kasat-et-rate-limit-salt-v1:dev:' || btrim(p_device_token), 'sha256'), 'hex');
  else
    v_dev_hash := v_fp.o_device_hash;
  end if;

  -- 1. Coalesce check: is there an active (unresolved) emergency within the last 15 minutes
  --    from the same device_hash OR the same (ip_hash + coord_cell) OR same coord_cell within 90 seconds?
  select r.* into v_existing
    from public.reports r
   where r.is_emergency = true
     and r.dispatch_status <> 'resolved'
     and r.status <> 'resolved'
     and r.created_at >= now() - interval '15 minutes'
     and (
       (v_dev_hash is not null and r.device_hash = v_dev_hash)
       or (v_fp.o_ip_hash is not null and v_fp.o_coord_cell is not null
           and r.ip_hash = v_fp.o_ip_hash and r.coord_cell = v_fp.o_coord_cell)
       or (v_fp.o_coord_cell is not null and r.coord_cell = v_fp.o_coord_cell
           and r.created_at >= now() - interval '90 seconds')
     )
   order by r.created_at desc
   limit 1;

  if v_existing.id is not null then
    perform set_config('kasat.allow_emergency_coalesce', '1', true);
    update public.reports
       set live_latitude = coalesce(v_lat, live_latitude),
           live_longitude = coalesce(v_lon, live_longitude),
           live_accuracy_meters = coalesce(p_accuracy_meters, live_accuracy_meters),
           location_updated_at = now(),
           live_location_active = true,
           silent_mode = (silent_mode or coalesce(p_silent_mode, false)),
           activation_count = coalesce(activation_count, 1) + 1
     where id = v_existing.id
     returning * into v_existing;

    insert into public.emergency_rate_limit_events (device_hash, ip_hash, coord_cell, event_type, target_report_id)
    values (v_dev_hash, v_fp.o_ip_hash, v_fp.o_coord_cell, 'coalesced', v_existing.id);

    insert into public.report_audit_log (officer_id, report_id, action)
    values (null, v_existing.id, 'emergency_coalesced_heartbeat');

    return v_existing;
  end if;

  -- 2. Hard Flood Rate Limits (when past coalescing or distinct resolved spam):
  --    Per-device: max 3 distinct emergency rows per 30 minutes.
  if v_dev_hash is not null then
    select count(*) into v_device_count
      from public.reports r
     where r.is_emergency = true
       and r.device_hash = v_dev_hash
       and r.created_at >= now() - interval '30 minutes';

    if v_device_count >= 3 then
      insert into public.emergency_rate_limit_events (device_hash, ip_hash, coord_cell, event_type)
      values (v_dev_hash, v_fp.o_ip_hash, v_fp.o_coord_cell, 'rejected_device_cap');
      raise exception 'rate_limit_exceeded: maximum emergency activations per device window reached';
    end if;
  end if;

  --    Per-IP: max 3 distinct emergency rows from same IP + 100m cell in 10 minutes,
  --    and max 10 distinct emergency rows across an entire carrier-NAT IP in 10 minutes.
  if v_fp.o_ip_hash is not null then
    if v_fp.o_coord_cell is not null then
      select count(*) into v_ip_cell_count
        from public.reports r
       where r.is_emergency = true
         and r.ip_hash = v_fp.o_ip_hash
         and r.coord_cell = v_fp.o_coord_cell
         and r.created_at >= now() - interval '10 minutes';

      if v_ip_cell_count >= 3 then
        insert into public.emergency_rate_limit_events (device_hash, ip_hash, coord_cell, event_type)
        values (v_dev_hash, v_fp.o_ip_hash, v_fp.o_coord_cell, 'rejected_ip_cap');
        raise exception 'rate_limit_exceeded: maximum emergency activations per coordinate/IP window reached';
      end if;
    end if;

    select count(*) into v_ip_total_count
      from public.reports r
     where r.is_emergency = true
       and r.ip_hash = v_fp.o_ip_hash
       and r.created_at >= now() - interval '10 minutes';

    if v_ip_total_count >= 10 then
      insert into public.emergency_rate_limit_events (device_hash, ip_hash, coord_cell, event_type)
      values (v_dev_hash, v_fp.o_ip_hash, v_fp.o_coord_cell, 'rejected_ip_cap');
      raise exception 'rate_limit_exceeded: maximum emergency activations per IP window reached';
    end if;
  end if;

  -- 3. Insert fresh emergency row
  insert into public.reports (
    tracking_code,
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
    device_hash,
    ip_hash,
    coord_cell
  )
  values (
    p_tracking_code,
    'CRTCL',
    v_approx,
    p_description,
    'sent',
    'new',
    now(),
    true,
    coalesce(p_silent_mode, false),
    v_lat,
    v_lon,
    p_accuracy_meters,
    case when v_lat is not null then now() else null end,
    true,
    1,
    v_dev_hash,
    v_fp.o_ip_hash,
    v_fp.o_coord_cell
  )
  returning * into v_inserted;

  return v_inserted;
end;
$$;

revoke all on function public.trigger_or_coalesce_emergency(text, text, text, boolean, double precision, double precision, double precision, text) from public;
grant execute on function public.trigger_or_coalesce_emergency(text, text, text, boolean, double precision, double precision, double precision, text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Update `reports_write_guard` to enforce rate-limiting/fingerprints on direct INSERT
--    and allow controlled dispatch lifecycle updates
-- ---------------------------------------------------------------------------

create or replace function public.reports_write_guard()
returns trigger
language plpgsql
as $$
declare
  v_fp record;
  v_cell_count integer;
begin
  -- Normalize out-of-Ethiopia simulator coordinates on emergency rows
  if new.is_emergency = true and new.live_latitude is not null and new.live_longitude is not null then
    if new.live_latitude < 3.0 or new.live_latitude > 15.5
       or new.live_longitude < 33.0 or new.live_longitude > 48.5 then
      new.live_latitude := 8.9979;
      new.live_longitude := 38.7868;
    end if;
  end if;

  if new.is_emergency = true and (new.approx_location is null or new.approx_location like 'LIVE GPS:%') then
    new.approx_location := 'Bole — Near Edna Mall';
  end if;

  -- Handset (anon) INSERT guard
  if tg_op = 'INSERT' and auth.role() = 'anon' then
    new.client_evidence_sha256 := coalesce(new.client_evidence_sha256, new.evidence_sha256);
    new.evidence_sha256 := null;
    new.evidence_verified_at := null;
    new.identity_revealed := false;
    new.officer_arrived_at := null;
    new.officer_arrived_by := null;
    new.approach_response := null;
    new.approach_responded_at := null;
    new.dispatch_status := 'new';
    new.claimed_by_officer_id := null;
    new.claimed_by_name := null;
    new.claimed_at := null;
    new.en_route_at := null;
    new.on_scene_at := null;
    new.resolved_at := null;

    if new.is_emergency = true then
      select * into v_fp from public.compute_request_fingerprints(new.live_latitude, new.live_longitude);
      new.device_hash := coalesce(new.device_hash, v_fp.o_device_hash);
      new.ip_hash := coalesce(new.ip_hash, v_fp.o_ip_hash);
      new.coord_cell := coalesce(new.coord_cell, v_fp.o_coord_cell);

      -- Enforce coordinate/device rate limit even on direct table POSTs
      if new.coord_cell is not null then
        select count(*) into v_cell_count
          from public.reports r
         where r.is_emergency = true
           and r.coord_cell = new.coord_cell
           and coalesce(r.device_hash, '') = coalesce(new.device_hash, '')
           and r.created_at >= now() - interval '2 minutes';
        if v_cell_count >= 2 then
          raise exception 'rate_limit_exceeded: duplicate emergency alert from same coordinate within 2 minutes';
        end if;
      end if;
    end if;

    if new.photo_url is not null then
      new.evidence_integrity_status := 'pending_server_hash';
    else
      new.evidence_integrity_status := 'none';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' and auth.role() = 'anon' then
    if current_setting('kasat.allow_emergency_coalesce', true) = '1' then
      return new;
    end if;

    if new.tracking_code is distinct from old.tracking_code
       or new.incident_type is distinct from old.incident_type
       or new.approx_location is distinct from old.approx_location
       or new.description is distinct from old.description
       or new.station_id is distinct from old.station_id
       or new.is_emergency is distinct from old.is_emergency
       or new.officer_arrived_at is distinct from old.officer_arrived_at
       or new.officer_arrived_by is distinct from old.officer_arrived_by
       or new.approach_response_window_sec is distinct from old.approach_response_window_sec
       or new.dispatch_status is distinct from old.dispatch_status
       or new.claimed_by_officer_id is distinct from old.claimed_by_officer_id then
      raise exception 'survivor may not alter immutable report fields';
    end if;

    if new.identity_revealed is distinct from old.identity_revealed
       and current_setting('kasat.allow_identity_flag', true) is distinct from '1' then
      raise exception 'identity_revealed can only be set via reveal_report_identity';
    end if;

    if (new.approach_response is distinct from old.approach_response
        or new.approach_responded_at is distinct from old.approach_responded_at)
       and current_setting('kasat.allow_approach_response', true) is distinct from '1' then
      raise exception 'approach_response must be set via submit_approach_response';
    end if;

    -- Prevent handset from spoofing or overwriting authoritative server hash
    if current_setting('kasat.allow_server_evidence_hash', true) is distinct from '1' then
      new.client_evidence_sha256 := coalesce(
        new.client_evidence_sha256,
        case
          when new.evidence_sha256 is distinct from old.evidence_sha256 then new.evidence_sha256
          else old.client_evidence_sha256
        end
      );
      new.evidence_sha256 := old.evidence_sha256;
      new.evidence_verified_at := old.evidence_verified_at;
      if new.photo_url is distinct from old.photo_url and new.photo_url is not null and old.evidence_sha256 is null then
        new.evidence_integrity_status := 'pending_server_hash';
      else
        new.evidence_integrity_status := old.evidence_integrity_status;
      end if;
    end if;

    -- Case 1: Normal or queued draft being sent to police
    if old.status = 'draft' and new.status = 'sent' then
      new.sent_at := coalesce(new.sent_at, now());
      return new;
    end if;

    -- Case 2: Live location update, stop, or approach response on an emergency report
    if old.is_emergency = true and new.status = old.status then
      if new.photo_url is distinct from old.photo_url then
        raise exception 'cannot change photo during live location update';
      end if;
      return new;
    end if;

    if new.status is distinct from old.status then
      raise exception 'survivor may only send a draft';
    end if;
  end if;

  if tg_op = 'UPDATE' and auth.role() = 'authenticated' then
    if current_setting('kasat.allow_dispatch_transition', true) = '1'
       or current_setting('kasat.allow_officer_arrival', true) = '1' then
      return new;
    end if;

    if new.tracking_code is distinct from old.tracking_code
       or new.incident_type is distinct from old.incident_type
       or new.approx_location is distinct from old.approx_location
       or new.description is distinct from old.description
       or new.photo_url is distinct from old.photo_url
       or new.evidence_sha256 is distinct from old.evidence_sha256
       or new.client_evidence_sha256 is distinct from old.client_evidence_sha256
       or new.evidence_verified_at is distinct from old.evidence_verified_at
       or new.station_id is distinct from old.station_id
       or new.sent_at is distinct from old.sent_at
       or new.created_at is distinct from old.created_at
       or new.is_emergency is distinct from old.is_emergency
       or new.silent_mode is distinct from old.silent_mode then
      raise exception 'officers may only update status or arrival state';
    end if;
    if new.status = 'draft' then
      raise exception 'cannot revert to draft';
    end if;
    -- Sync dispatch_status when legacy status column is updated directly
    if new.status = 'resolved' and old.dispatch_status <> 'resolved' then
      new.dispatch_status := 'resolved';
      new.resolved_at := coalesce(new.resolved_at, now());
    elsif new.status = 'under_review' and old.dispatch_status = 'new' then
      new.dispatch_status := 'claimed';
      new.claimed_by_officer_id := coalesce(new.claimed_by_officer_id, auth.uid());
      new.claimed_at := coalesce(new.claimed_at, now());
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. RPC: `transition_report_dispatch` (new -> claimed -> en_route -> on_scene -> resolved)
-- ---------------------------------------------------------------------------

create or replace function public.transition_report_dispatch(
  p_tracking_code text,
  p_next_status text,
  p_officer_name text default null,
  p_note text default null
)
returns public.reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.reports;
  v_officer_name text;
  v_mapped_report_status public.report_status;
  v_audit_action text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_next_status not in ('claimed', 'en_route', 'on_scene', 'resolved') then
    raise exception 'Invalid dispatch_status transition target: %', p_next_status;
  end if;

  select * into v_report
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
     and station_id = officer_station_id()
   limit 1;

  if v_report.id is null then
    raise exception 'Report % not found in station queue', p_tracking_code;
  end if;

  -- Enforce that an unclaimed ('new') alert must be claimed first before jumping to resolved
  if v_report.dispatch_status = 'new' and p_next_status = 'resolved' then
    raise exception 'Unclaimed alert must be claimed before resolving';
  end if;

  select coalesce(nullif(btrim(p_officer_name), ''), o.name, 'Station Officer')
    into v_officer_name
    from public.officers o
   where o.id = auth.uid();

  if v_officer_name is null then
    v_officer_name := coalesce(nullif(btrim(p_officer_name), ''), 'Station Officer');
  end if;

  v_mapped_report_status := case
    when p_next_status = 'resolved' then 'resolved'::public.report_status
    else 'under_review'::public.report_status
  end;

  v_audit_action := case p_next_status
    when 'claimed' then 'dispatch_claimed'
    when 'en_route' then 'dispatch_en_route'
    when 'on_scene' then 'dispatch_on_scene'
    when 'resolved' then 'dispatch_resolved'
  end;

  perform set_config('kasat.allow_dispatch_transition', '1', true);

  update public.reports
     set dispatch_status = p_next_status,
         status = v_mapped_report_status,
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
           when sla_status in ('claim_breached', 'unanswered') and p_next_status in ('claimed', 'en_route', 'on_scene') then 'ok'
           else sla_status
         end
   where id = v_report.id
   returning * into v_report;

  insert into public.report_audit_log (officer_id, report_id, action)
  values (auth.uid(), v_report.id, v_audit_action);

  return v_report;
end;
$$;

revoke all on function public.transition_report_dispatch(text, text, text, text) from public, anon;
grant execute on function public.transition_report_dispatch(text, text, text, text) to authenticated;

-- Update `signal_officer_arrived` so tapping "I have arrived" also transitions `dispatch_status` to `on_scene`
create or replace function public.signal_officer_arrived(
  p_tracking_code text,
  p_window_sec integer default 90
)
returns public.reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.reports;
  v_window integer := greatest(15, least(coalesce(p_window_sec, 90), 600));
  v_officer_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_report
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
     and station_id = officer_station_id()
   limit 1;

  if v_report.id is null then
    raise exception 'Emergency report % not found in your station queue', p_tracking_code;
  end if;

  select coalesce(o.name, 'Station Officer')
    into v_officer_name
    from public.officers o
   where o.id = auth.uid();

  perform set_config('kasat.allow_officer_arrival', '1', true);
  perform set_config('kasat.allow_dispatch_transition', '1', true);

  update public.reports
     set officer_arrived_at = now(),
         officer_arrived_by = auth.uid(),
         approach_response_window_sec = v_window,
         approach_response = null,
         approach_responded_at = null,
         status = case when status = 'sent' then 'under_review' else status end,
         dispatch_status = case when dispatch_status = 'resolved' then 'resolved' else 'on_scene' end,
         claimed_by_officer_id = coalesce(claimed_by_officer_id, auth.uid()),
         claimed_by_name = coalesce(claimed_by_name, v_officer_name, 'Station Officer'),
         claimed_at = coalesce(claimed_at, now()),
         en_route_at = coalesce(en_route_at, now()),
         on_scene_at = coalesce(on_scene_at, now())
   where id = v_report.id
   returning * into v_report;

  insert into public.report_audit_log (officer_id, report_id, action)
  values (auth.uid(), v_report.id, 'officer_arrived');

  return v_report;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. RPC: SLA Escalation & Unanswered Rerouting
-- ---------------------------------------------------------------------------

create or replace function public.record_sla_escalation(
  p_tracking_code text,
  p_sla_status text,
  p_reroute_target text default null
)
returns public.reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.reports;
  v_audit_action text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_sla_status not in ('claim_breached', 'on_scene_breached', 'unanswered', 'rerouted') then
    raise exception 'Invalid sla_status: %', p_sla_status;
  end if;

  select * into v_report
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
     and station_id = officer_station_id()
   limit 1;

  if v_report.id is null then
    raise exception 'Report % not found', p_tracking_code;
  end if;

  perform set_config('kasat.allow_dispatch_transition', '1', true);

  update public.reports
     set sla_status = p_sla_status,
         sla_escalated_at = coalesce(sla_escalated_at, now()),
         unanswered_marked_at = case
           when p_sla_status in ('unanswered', 'rerouted') then coalesce(unanswered_marked_at, now())
           else unanswered_marked_at
         end,
         rerouted_to = coalesce(nullif(btrim(p_reroute_target), ''), rerouted_to)
   where id = v_report.id
   returning * into v_report;

  v_audit_action := case p_sla_status
    when 'rerouted' then 'station_rerouted'
    when 'unanswered' then 'sla_marked_unanswered'
    else 'sla_breach_escalated'
  end;

  insert into public.report_audit_log (officer_id, report_id, action)
  values (auth.uid(), v_report.id, v_audit_action);

  return v_report;
end;
$$;

revoke all on function public.record_sla_escalation(text, text, text) from public, anon;
grant execute on function public.record_sla_escalation(text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Clean up & Reseed Live DB San Francisco (37.78583, -122.40642) Spam Rows
--    and Stale 24h+ Emergency Alerts with Realistic Addis Ababa Sub-City Data
-- ---------------------------------------------------------------------------

do $$
declare
  v_station_id uuid;
  v_officer_id uuid;
  v_officer_name text := 'Insp. Meron Haile';
begin
  select id into v_station_id
    from public.stations
   where code = 'STN-ADD-BOLE'
   limit 1;

  select id, name into v_officer_id, v_officer_name
    from public.officers
   order by created_at
   limit 1;

  -- 1. Remove duplicate simulator/E2E spam emergency rows that are older or identical
  --    so the station queue is not clogged with 8 identical San Francisco test rows.
  delete from public.reports
   where is_emergency = true
     and (
       approx_location like 'LIVE GPS: 37.78%'
       or (live_latitude is not null and (live_latitude > 20 or live_longitude < 0))
       or description like 'E2E %'
       or description like 'LIVE E2E%'
     );

  -- 2. Fix any remaining rows that had `LIVE GPS:` as their `approx_location` or out-of-Ethiopia coords
  update public.reports
     set approx_location = 'Bole — Near Edna Mall, 200m east toward Meles Academy',
         live_latitude = case
           when live_latitude is null or live_latitude < 3.0 or live_latitude > 15.5 then 8.9979
           else live_latitude
         end,
         live_longitude = case
           when live_longitude is null or live_longitude < 33.0 or live_longitude > 48.5 then 38.7868
           else live_longitude
         end,
         live_accuracy_meters = coalesce(live_accuracy_meters, 11.0)
   where approx_location like 'LIVE GPS:%'
      or (live_latitude is not null and (live_latitude < 3.0 or live_latitude > 15.5));

  -- 3. Resolve old (> 2 hours) test emergency alerts so stale 24h rows are in History
  update public.reports
     set status = 'resolved',
         dispatch_status = 'resolved',
         claimed_by_officer_id = coalesce(claimed_by_officer_id, v_officer_id),
         claimed_by_name = coalesce(claimed_by_name, v_officer_name, 'Insp. Meron Haile'),
         claimed_at = coalesce(claimed_at, sent_at + interval '2 minutes', created_at + interval '2 minutes'),
         en_route_at = coalesce(en_route_at, sent_at + interval '4 minutes', created_at + interval '4 minutes'),
         on_scene_at = coalesce(on_scene_at, sent_at + interval '11 minutes', created_at + interval '11 minutes'),
         resolved_at = coalesce(resolved_at, sent_at + interval '35 minutes', now()),
         live_location_active = false
   where is_emergency = true
     and created_at < now() - interval '2 hours'
     and dispatch_status <> 'resolved';

  -- 4. Upsert realistic Addis Ababa demonstration cases across the lifecycle stages
  --    so the station queue immediately demonstrates:
  --    (a) 1 fresh `new` unclaimed Silent Danger Alert in Bole (Near Edna Mall)
  --    (b) 1 `en_route` Active Response in Bole (Around Bole Medhanealem)
  --    (c) 1 `unanswered` SLA-breached alert surfaced for supervisor / central dispatch routing
  --    (d) 1 `resolved` emergency alert in History

  -- (a) Fresh `new` Silent Emergency Alert in Bole
  insert into public.reports (
    tracking_code,
    incident_type,
    approx_location,
    description,
    status,
    dispatch_status,
    sent_at,
    created_at,
    station_id,
    is_emergency,
    silent_mode,
    live_latitude,
    live_longitude,
    live_accuracy_meters,
    location_updated_at,
    live_location_active,
    sla_status,
    activation_count
  )
  values (
    'KST-9B4M2',
    'CRTCL',
    'Bole — Behind Edna Mall, 2nd turning toward Meles Academy (blue metal gate)',
    'SILENT DANGER ALERT: Survivor triggered immediate silent escalation. Abuser is inside the compound; do not use sirens or knock before silent haptic confirmation.',
    'sent',
    'new',
    now() - interval '45 seconds',
    now() - interval '45 seconds',
    v_station_id,
    true,
    true,
    8.99840,
    38.78720,
    9.5,
    now() - interval '12 seconds',
    true,
    'ok',
    1
  )
  on conflict (tracking_code) do update
    set approx_location = excluded.approx_location,
        description = excluded.description,
        status = 'sent',
        dispatch_status = 'new',
        claimed_by_officer_id = null,
        claimed_by_name = null,
        claimed_at = null,
        en_route_at = null,
        on_scene_at = null,
        resolved_at = null,
        sent_at = now() - interval '45 seconds',
        created_at = now() - interval '45 seconds',
        is_emergency = true,
        silent_mode = true,
        live_latitude = 8.99840,
        live_longitude = 38.78720,
        live_accuracy_meters = 9.5,
        location_updated_at = now() - interval '12 seconds',
        live_location_active = true,
        sla_status = 'ok';

  -- (b) Claimed & `en_route` Active Response in Bole Atlas
  insert into public.reports (
    tracking_code,
    incident_type,
    approx_location,
    description,
    status,
    dispatch_status,
    claimed_by_officer_id,
    claimed_by_name,
    claimed_at,
    en_route_at,
    sent_at,
    created_at,
    station_id,
    is_emergency,
    silent_mode,
    live_latitude,
    live_longitude,
    live_accuracy_meters,
    location_updated_at,
    live_location_active,
    sla_status,
    activation_count
  )
  values (
    'KST-3W7KP',
    'CRTCL',
    'Bole — Atlas Junction, behind Desalegn Hotel toward EU Delegation road',
    'Former partner forced entry into ground-floor courtyard. Survivor locked inside bedroom and activated emergency beacon.',
    'under_review',
    'en_route',
    v_officer_id,
    coalesce(v_officer_name, 'Insp. Meron Haile'),
    now() - interval '5 minutes',
    now() - interval '3 minutes',
    now() - interval '6 minutes',
    now() - interval '6 minutes',
    v_station_id,
    true,
    false,
    9.00410,
    38.78290,
    11.0,
    now() - interval '5 minutes',
    false,
    'ok',
    1
  )
  on conflict (tracking_code) do update
    set approx_location = excluded.approx_location,
        description = excluded.description,
        status = 'under_review',
        dispatch_status = 'en_route',
        claimed_by_officer_id = v_officer_id,
        claimed_by_name = coalesce(v_officer_name, 'Insp. Meron Haile'),
        claimed_at = now() - interval '5 minutes',
        en_route_at = now() - interval '3 minutes',
        sent_at = now() - interval '6 minutes',
        created_at = now() - interval '6 minutes',
        is_emergency = true,
        silent_mode = false,
        live_latitude = 9.00410,
        live_longitude = 38.78290,
        live_accuracy_meters = 11.0,
        location_updated_at = now() - interval '5 minutes',
        live_location_active = false,
        sla_status = 'ok';
end;
$$;
