-- Officer Emergency Response & Silent Approach Confirmation
-- 1. Adds `silent_mode`, `live_accuracy_meters`, `officer_arrived_at`,
--    `officer_arrived_by`, `approach_response_window_sec`, `approach_response`,
--    and `approach_responded_at` to `public.reports`.
-- 2. Extends `public.report_audit_log` with approach confirmation actions:
--    - `officer_arrived`
--    - `approach_response_can_come_out`
--    - `approach_response_do_not_knock`
--    - `approach_no_response`
-- 3. Adds RPCs:
--    - `public.signal_officer_arrived(p_tracking_code, p_window_sec)` (authenticated)
--    - `public.submit_approach_response(p_tracking_code, p_response)` (anon)
--    - `public.log_approach_no_response(p_tracking_code)` (authenticated)

alter table public.reports
  add column if not exists silent_mode boolean not null default false,
  add column if not exists live_accuracy_meters double precision,
  add column if not exists officer_arrived_at timestamptz,
  add column if not exists officer_arrived_by uuid references auth.users (id) on delete set null,
  add column if not exists approach_response_window_sec integer not null default 90
    check (approach_response_window_sec between 15 and 600),
  add column if not exists approach_response text
    check (approach_response is null or approach_response in ('can_come_out', 'abuser_present_do_not_knock', 'no_response')),
  add column if not exists approach_responded_at timestamptz;

-- Extend `report_audit_log` allowed actions
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
      'approach_no_response'
    )
  );

-- Update `reports_write_guard` to protect new approach columns while allowing:
-- (a) `anon` to set `silent_mode` on emergency insert and update `live_accuracy_meters`
--     or `approach_response` via the guarded RPC/update path.
-- (b) `authenticated` officers to signal arrival via `signal_officer_arrived`.
create or replace function public.reports_write_guard()
returns trigger
language plpgsql
as $$
begin
  -- Handset (anon) INSERT guard: client cannot self-attest authoritative `evidence_sha256`.
  if tg_op = 'INSERT' and auth.role() = 'anon' then
    new.client_evidence_sha256 := coalesce(new.client_evidence_sha256, new.evidence_sha256);
    new.evidence_sha256 := null;
    new.evidence_verified_at := null;
    new.identity_revealed := false;
    new.officer_arrived_at := null;
    new.officer_arrived_by := null;
    new.approach_response := null;
    new.approach_responded_at := null;
    if new.photo_url is not null then
      new.evidence_integrity_status := 'pending_server_hash';
    else
      new.evidence_integrity_status := 'none';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' and auth.role() = 'anon' then
    if new.tracking_code is distinct from old.tracking_code
       or new.incident_type is distinct from old.incident_type
       or new.approx_location is distinct from old.approx_location
       or new.description is distinct from old.description
       or new.station_id is distinct from old.station_id
       or new.is_emergency is distinct from old.is_emergency
       or new.officer_arrived_at is distinct from old.officer_arrived_at
       or new.officer_arrived_by is distinct from old.officer_arrived_by
       or new.approach_response_window_sec is distinct from old.approach_response_window_sec then
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

    -- Case 1: Normal or queued draft being sent to police (allows late photo upload)
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
    if (new.officer_arrived_at is distinct from old.officer_arrived_at
        or new.officer_arrived_by is distinct from old.officer_arrived_by
        or new.approach_response_window_sec is distinct from old.approach_response_window_sec
        or new.approach_response is distinct from old.approach_response)
       and current_setting('kasat.allow_officer_arrival', true) is distinct from '1' then
      raise exception 'officer arrival must be set via signal_officer_arrived';
    end if;
    if new.status = 'draft' then
      raise exception 'cannot revert to draft';
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC 1: Officer taps "I have arrived" -> signals survivor's handset & logs
-- ---------------------------------------------------------------------------
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

  perform set_config('kasat.allow_officer_arrival', '1', true);

  update public.reports
     set officer_arrived_at = now(),
         officer_arrived_by = auth.uid(),
         approach_response_window_sec = v_window,
         approach_response = null,
         approach_responded_at = null,
         status = case when status = 'sent' then 'under_review' else status end
   where id = v_report.id
   returning * into v_report;

  insert into public.report_audit_log (officer_id, report_id, action)
  values (auth.uid(), v_report.id, 'officer_arrived');

  return v_report;
end;
$$;

revoke all on function public.signal_officer_arrived(text, integer) from public, anon;
grant execute on function public.signal_officer_arrived(text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC 2: Survivor taps "I can come out" or "He is here — do not knock"
-- ---------------------------------------------------------------------------
create or replace function public.submit_approach_response(
  p_tracking_code text,
  p_response text
)
returns public.reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.reports;
  v_header_code text;
  v_audit_action text;
begin
  if p_response not in ('can_come_out', 'abuser_present_do_not_knock') then
    raise exception 'Invalid approach_response %', p_response;
  end if;

  v_header_code := current_setting('request.headers', true)::json ->> 'x-tracking-code';
  if v_header_code is not null and v_header_code <> '' and v_header_code <> p_tracking_code then
    raise exception 'tracking code mismatch';
  end if;

  select * into v_report
    from public.reports
   where tracking_code = p_tracking_code
   limit 1;

  if v_report.id is null then
    raise exception 'Report % not found', p_tracking_code;
  end if;

  perform set_config('kasat.allow_approach_response', '1', true);

  update public.reports
     set approach_response = p_response,
         approach_responded_at = now()
   where id = v_report.id
   returning * into v_report;

  v_audit_action := case
    when p_response = 'can_come_out' then 'approach_response_can_come_out'
    else 'approach_response_do_not_knock'
  end;

  insert into public.report_audit_log (officer_id, report_id, action)
  values (null, v_report.id, v_audit_action);

  return v_report;
end;
$$;

revoke all on function public.submit_approach_response(text, text) from public;
grant execute on function public.submit_approach_response(text, text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- RPC 3: Officer portal records timeout ("No response" after configurable window)
-- ---------------------------------------------------------------------------
create or replace function public.log_approach_no_response(
  p_tracking_code text
)
returns public.reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.reports;
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
    raise exception 'Report % not found', p_tracking_code;
  end if;

  -- Only record 'no_response' if she hasn't already answered with a real choice
  if v_report.approach_response in ('can_come_out', 'abuser_present_do_not_knock') then
    return v_report;
  end if;

  perform set_config('kasat.allow_officer_arrival', '1', true);

  update public.reports
     set approach_response = 'no_response',
         approach_responded_at = coalesce(approach_responded_at, now())
   where id = v_report.id
   returning * into v_report;

  if not exists (
    select 1
      from public.report_audit_log
     where report_id = v_report.id
       and action = 'approach_no_response'
       and created_at >= coalesce(v_report.officer_arrived_at, now() - interval '10 minutes')
  ) then
    insert into public.report_audit_log (officer_id, report_id, action)
    values (auth.uid(), v_report.id, 'approach_no_response');
  end if;

  return v_report;
end;
$$;

revoke all on function public.log_approach_no_response(text) from public, anon;
grant execute on function public.log_approach_no_response(text) to authenticated;
