-- Reseed existing demo report rows with varied Addis Ababa coordinates and landmarks
-- across different sub-cities, and remove unconditional coordinate clamping from DB triggers
-- so demo location override is controlled strictly by demo mode (--dart-define / portal demo mode).

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
set search_path = public, extensions
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
  v_approx text := coalesce(nullif(btrim(p_approx_location), ''), 'Bole — Near Bole Medhanealem & Edna Mall');
  v_inserted public.reports;
begin
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

  -- 2. Hard Flood Rate Limits:
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

-- Reseed all existing rows in `public.reports` with varied Addis Ababa sub-cities,
-- landmarks, and coordinates so no two demo rows share identical positions.
do $$
declare
  v_rec record;
  v_idx integer := 0;
  v_station_id uuid;
  v_officer_id uuid;
  v_officer_name text := 'Insp. Meron Haile';
  v_locations text[] := array[
    'Bole — Near Bole Medhanealem & Edna Mall (200m east toward Meles Academy)',
    'Kirkos — Meskel Square, behind St. Estifanos Church',
    'Arada — Piazza, near Cinema Ethiopia & DeGaulle Square',
    'Yeka — Megenagna, behind Zefmesh Grand Mall toward Egziabher Ab',
    'Lideta — Mexico Square, opposite Wabi Shebelle Hotel',
    'Nifas Silk-Lafto — Sarbet, near Pushkin Square & AU Gate',
    'Gulele — Shiro Meda, near US Embassy & Entoto road',
    'Lemi Kura — Ayat Roundabout, near CCE Residential Compound',
    'Addis Ketema — Merkato, near Raguel Church & Gojjam Berenda',
    'Kolfe Keraniyo — Ayer Tena Roundabout, toward Jemo 1 road',
    'Akaki Kality — Kality Total, near Kafdem Plaza'
  ];
  v_lats double precision[] := array[
    8.99500,
    9.00960,
    9.03310,
    9.02040,
    9.01180,
    8.98620,
    9.04880,
    9.01760,
    9.03120,
    9.00640,
    8.89520
  ];
  v_lons double precision[] := array[
    38.78900,
    38.76120,
    38.75240,
    38.80210,
    38.74450,
    38.74890,
    38.76180,
    38.84920,
    38.73880,
    38.70420,
    38.76950
  ];
  v_accuracies double precision[] := array[
    8.5, 11.0, 9.0, 12.5, 10.0, 9.5, 14.0, 11.5, 13.0, 10.5, 12.0
  ];
  v_slot integer;
begin
  select id into v_station_id
    from public.stations
   where code = 'STN-ADD-BOLE'
   limit 1;

  select id, name into v_officer_id, v_officer_name
    from public.officers
   order by created_at
   limit 1;

  -- Distribute every existing row across the 11 Addis Ababa sub-cities with distinct coordinates
  for v_rec in
    select id, tracking_code, is_emergency
      from public.reports
     order by created_at desc
  loop
    v_slot := (v_idx % 11) + 1;
    perform set_config('kasat.allow_dispatch_transition', '1', true);
    update public.reports
       set approx_location = v_locations[v_slot],
           live_latitude = case
             when is_emergency then v_lats[v_slot] + ((v_idx / 11) * 0.0004)
             else live_latitude
           end,
           live_longitude = case
             when is_emergency then v_lons[v_slot] + ((v_idx / 11) * 0.0004)
             else live_longitude
           end,
           live_accuracy_meters = case
             when is_emergency then v_accuracies[v_slot]
             else live_accuracy_meters
           end,
           coord_cell = case
             when is_emergency then round((v_lats[v_slot] + ((v_idx / 11) * 0.0004))::numeric, 3)::text || ',' || round((v_lons[v_slot] + ((v_idx / 11) * 0.0004))::numeric, 3)::text
             else coord_cell
           end
     where id = v_rec.id;
    v_idx := v_idx + 1;
  end loop;

  -- Ensure our flagship active demo emergency rows in the queue have distinct sub-cities & coordinates:
  -- 1. `KST-9B4M2`: `new` (unclaimed) Silent Emergency in Bole (8.9950, 38.7890)
  perform set_config('kasat.allow_dispatch_transition', '1', true);
  update public.reports
     set approx_location = 'Bole — Near Bole Medhanealem & Edna Mall (200m east toward Meles Academy)',
         live_latitude = 8.99500,
         live_longitude = 38.78900,
         live_accuracy_meters = 8.5,
         location_updated_at = now() - interval '15 seconds',
         live_location_active = true,
         dispatch_status = 'new',
         status = 'sent',
         claimed_by_officer_id = null,
         claimed_by_name = null,
         claimed_at = null,
         coord_cell = '8.995,38.789'
   where tracking_code = 'KST-9B4M2';

  -- 2. `KST-3W7KP`: `en_route` Active Response in Kirkos — Meskel Square (9.0096, 38.7612)
  update public.reports
     set approx_location = 'Kirkos — Meskel Square, behind St. Estifanos Church toward Bambis',
         live_latitude = 9.00960,
         live_longitude = 38.76120,
         live_accuracy_meters = 11.0,
         location_updated_at = now() - interval '5 minutes',
         live_location_active = false,
         dispatch_status = 'en_route',
         status = 'under_review',
         claimed_by_officer_id = v_officer_id,
         claimed_by_name = coalesce(v_officer_name, 'Insp. Meron Haile'),
         claimed_at = now() - interval '6 minutes',
         en_route_at = now() - interval '4 minutes',
         coord_cell = '9.010,38.761'
   where tracking_code = 'KST-3W7KP';

  -- 3. Upsert a 3rd active response (`on_scene`) in Yeka — Megenagna (9.0204, 38.8021)
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
    on_scene_at,
    officer_arrived_at,
    officer_arrived_by,
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
    activation_count,
    coord_cell
  )
  values (
    'KST-7Y2MN',
    'CRTCL',
    'Yeka — Megenagna, behind Zefmesh Grand Mall toward Egziabher Ab',
    'SILENT DANGER ALERT: Survivor locked inside rear courtyard room near Zefmesh Grand Mall. Officer on scene awaiting silent approach confirmation.',
    'under_review',
    'on_scene',
    v_officer_id,
    'Sgt. Dawit Bekele',
    now() - interval '9 minutes',
    now() - interval '7 minutes',
    now() - interval '1 minute',
    now() - interval '30 seconds',
    v_officer_id,
    now() - interval '10 minutes',
    now() - interval '10 minutes',
    v_station_id,
    true,
    true,
    9.02040,
    38.80210,
    9.0,
    now() - interval '20 seconds',
    true,
    'ok',
    1,
    '9.020,38.802'
  )
  on conflict (tracking_code) do update
    set approx_location = excluded.approx_location,
        description = excluded.description,
        status = 'under_review',
        dispatch_status = 'on_scene',
        claimed_by_officer_id = v_officer_id,
        claimed_by_name = 'Sgt. Dawit Bekele',
        claimed_at = now() - interval '9 minutes',
        en_route_at = now() - interval '7 minutes',
        on_scene_at = now() - interval '1 minute',
        officer_arrived_at = now() - interval '30 seconds',
        live_latitude = 9.02040,
        live_longitude = 38.80210,
        live_accuracy_meters = 9.0,
        location_updated_at = now() - interval '20 seconds',
        live_location_active = true,
        coord_cell = '9.020,38.802';
end;
$$;
