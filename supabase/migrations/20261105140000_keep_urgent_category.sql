-- An urgent report keeps the category the survivor chose.
-- is_emergency is the only urgent flag. CRTCL is not written in its place.

drop function if exists public.create_draft_report(text, text, text, text, text, text);

create or replace function public.create_draft_report(
  p_incident_type text,
  p_description text,
  p_approx_location text default null,
  p_photo_url text default null,
  p_client_sha256 text default null,
  p_tracking_code text default null,
  p_is_emergency boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  v_code text;
  v_type text := nullif(btrim(coalesce(p_incident_type, '')), '');
begin
  if v_type is null or v_type = 'CRTCL' then
    raise exception 'category required';
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
    photo_url,
    status,
    client_evidence_sha256,
    evidence_integrity_status,
    is_emergency
  )
  values (
    v_code,
    public._new_access_secret(),
    v_type,
    nullif(btrim(coalesce(p_approx_location, '')), ''),
    p_description,
    nullif(btrim(coalesce(p_photo_url, '')), ''),
    'draft',
    nullif(lower(btrim(coalesce(p_client_sha256, ''))), ''),
    case when p_photo_url is not null and btrim(p_photo_url) <> '' then 'pending_server_hash' else 'none' end,
    coalesce(p_is_emergency, false)
  )
  returning * into r;

  return public._survivor_report_json(r, true);
end;
$$;

revoke all on function public.create_draft_report(text, text, text, text, text, text, boolean) from public;
grant execute on function public.create_draft_report(text, text, text, text, text, text, boolean) to anon, authenticated;

drop function if exists public.trigger_or_coalesce_emergency(text, text, boolean, double precision, double precision, double precision, text, text, text);

create or replace function public.trigger_or_coalesce_emergency(
  p_description text,
  p_approx_location text default null,
  p_silent_mode boolean default false,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_accuracy_meters double precision default null,
  p_device_secret text default null,
  p_tracking_code text default null,
  p_access_secret text default null,
  p_incident_type text default null
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
  v_approx text := nullif(btrim(coalesce(p_approx_location, '')), '');
  v_code text;
  v_type text := nullif(btrim(coalesce(p_incident_type, '')), '');
begin
  if v_type is null or v_type = 'CRTCL' then
    v_type := 'other';
  end if;
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
    v_type,
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

revoke all on function public.trigger_or_coalesce_emergency(text, text, boolean, double precision, double precision, double precision, text, text, text, text) from public, anon, authenticated;
grant execute on function public.trigger_or_coalesce_emergency(text, text, boolean, double precision, double precision, double precision, text, text, text, text) to service_role;

notify pgrst, 'reload schema';
