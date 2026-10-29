-- Issue 2: Move Evidence Hashing Server-Side
-- Chain of custody must not depend on trusting the handset.
-- 1. `client_evidence_sha256` stores the handset's post-scrub SHA-256 strictly as a
--    transport-integrity check.
-- 2. `evidence_sha256` is the authoritative hash computed server-side from the
--    actual bytes received in `report-photos` storage.
-- 3. `reports_write_guard` blocks `anon` from ever setting `evidence_sha256` or
--    `evidence_verified_at` directly. Only `service_role` (via the `verify-evidence`
--    Edge Function / `record_server_evidence_hash`) can write the authoritative hash.

alter table public.reports
  add column if not exists client_evidence_sha256 text,
  add column if not exists evidence_verified_at timestamptz,
  add column if not exists evidence_integrity_status text not null default 'none'
    check (evidence_integrity_status in ('none', 'pending_server_hash', 'verified', 'mismatch'));

-- Update `report_audit_log` check constraint to include server-side evidence hashing events.
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
      'evidence_hash_mismatch'
    )
  );

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
       or new.is_emergency is distinct from old.is_emergency then
      raise exception 'survivor may not alter immutable report fields';
    end if;

    if new.identity_revealed is distinct from old.identity_revealed
       and current_setting('kasat.allow_identity_flag', true) is distinct from '1' then
      raise exception 'identity_revealed can only be set via reveal_report_identity';
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

    -- Case 2: Live location update or stop on an emergency report
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

-- Server-only RPC invoked by the `verify-evidence` Edge Function after reading
-- the actual object bytes from `report-photos` and computing SHA-256 on the server.
create or replace function public.record_server_evidence_hash(
  p_tracking_code text,
  p_photo_url text,
  p_server_sha256 text,
  p_client_sha256 text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.reports;
  v_server_hash text := lower(btrim(p_server_sha256));
  v_client_hash text;
  v_status text;
  v_now timestamptz := now();
begin
  if v_server_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid server sha256 digest';
  end if;

  select * into v_report
    from public.reports
   where tracking_code = p_tracking_code
   limit 1;

  if v_report.id is null then
    raise exception 'report not found for tracking_code %', p_tracking_code;
  end if;

  v_client_hash := lower(btrim(coalesce(p_client_sha256, v_report.client_evidence_sha256, '')));
  if v_client_hash = '' then
    v_client_hash := null;
    v_status := 'verified';
  elsif v_client_hash = v_server_hash then
    v_status := 'verified';
  else
    v_status := 'mismatch';
  end if;

  perform set_config('kasat.allow_server_evidence_hash', '1', true);

  update public.reports
     set photo_url = coalesce(p_photo_url, photo_url),
         evidence_sha256 = v_server_hash,
         client_evidence_sha256 = coalesce(v_client_hash, client_evidence_sha256),
         evidence_verified_at = v_now,
         evidence_integrity_status = v_status
   where id = v_report.id
   returning * into v_report;

  insert into public.report_audit_log (officer_id, report_id, action)
  values (
    null,
    v_report.id,
    case when v_status = 'verified' then 'evidence_hashed' else 'evidence_hash_mismatch' end
  );

  return jsonb_build_object(
    'report_id', v_report.id,
    'tracking_code', v_report.tracking_code,
    'evidence_sha256', v_report.evidence_sha256,
    'client_evidence_sha256', v_report.client_evidence_sha256,
    'evidence_verified_at', v_report.evidence_verified_at,
    'evidence_integrity_status', v_report.evidence_integrity_status,
    'transport_match', (v_status = 'verified')
  );
end;
$$;

-- Strictly restrict `record_server_evidence_hash` to `service_role` so clients
-- cannot call it directly via PostgREST with an anon or officer JWT.
revoke all on function public.record_server_evidence_hash(text, text, text, text) from public, anon, authenticated;
grant execute on function public.record_server_evidence_hash(text, text, text, text) to service_role;
