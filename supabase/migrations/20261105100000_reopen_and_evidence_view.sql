-- Reopen a resolved case, and serve survivor photos only after claim
-- through a short-lived signed URL. The sign step requires a fresh
-- evidence_viewed audit row, so a view cannot skip the log.

alter table public.report_audit_log
  add column if not exists detail text;

alter table public.report_audit_log
  drop constraint if exists report_audit_log_detail_len;
alter table public.report_audit_log
  add constraint report_audit_log_detail_len
  check (detail is null or char_length(detail) between 1 and 500);

-- Previous check is 20261105070407_officer_case_notes.sql, plus these two.
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
      'location_unlock',
      'reply',
      'note',
      'reopened',
      'evidence_viewed'
    )
  );

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
           'isSpaceAdmin', o.is_space_admin,
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

create or replace function public.reopen_case(p_tracking_code text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sid uuid := public._require_officer();
  r public.reports;
  allowed boolean := false;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if char_length(v_reason) not between 1 and 280 then
    raise exception 'reason required';
  end if;

  select * into r
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
     and station_id = sid
   for update;
  if r.id is null then
    raise exception 'not found';
  end if;
  if r.dispatch_status is distinct from 'resolved' and r.status is distinct from 'resolved' then
    raise exception 'not resolved';
  end if;

  select
    r.claimed_by_officer_id is not distinct from auth.uid()
    or exists (
      select 1
        from public.officers o
       where o.id = auth.uid()
         and o.is_space_admin
         and o.station_id is not distinct from r.station_id
    )
    into allowed;
  if allowed is not true then
    raise exception 'not allowed';
  end if;

  update public.reports
     set dispatch_status = 'claimed',
         status = 'under_review'
   where id = r.id
   returning * into r;

  insert into public.report_audit_log (officer_id, report_id, action, detail)
  values (auth.uid(), r.id, 'reopened', v_reason);

  return public._officer_report_json(r, r.claimed_by_officer_id is not distinct from auth.uid());
end;
$$;
revoke all on function public.reopen_case(text, text) from public, anon;
grant execute on function public.reopen_case(text, text) to authenticated;

-- A resolved case cannot be moved by the ordinary status button.
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
  if r.dispatch_status = 'resolved' or r.status = 'resolved' then
    raise exception 'resolved cases reopen with a reason';
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

create or replace function public._case_attachment_files(r public.reports)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  files jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
           'object_key', s.name,
           'integrity_status', case
             when s.name = r.photo_url then r.evidence_integrity_status::text
             else null
           end,
           'evidence_sha256', case
             when s.name = r.photo_url then r.evidence_sha256
             else null
           end
         ) order by s.name), '[]'::jsonb)
    into files
    from storage.objects s
   where s.bucket_id = 'report-photos'
     and split_part(s.name, '/', 1) = r.tracking_code
     and position('..' in s.name) = 0;

  if r.photo_url is not null
     and btrim(r.photo_url) <> ''
     and not exists (
       select 1
         from jsonb_array_elements(files) item
        where item->>'object_key' = r.photo_url
     ) then
    files := files || jsonb_build_array(jsonb_build_object(
      'object_key', r.photo_url,
      'integrity_status', r.evidence_integrity_status::text,
      'evidence_sha256', r.evidence_sha256
    ));
  end if;
  return files;
end;
$$;
revoke all on function public._case_attachment_files(public.reports) from public, anon, authenticated;

create or replace function public.case_attachment_summary(p_tracking_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  sid uuid := public._require_officer();
  r public.reports;
  files jsonb;
  claimed boolean;
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
  files := public._case_attachment_files(r);
  claimed := r.dispatch_status is distinct from 'new' and r.claimed_by_officer_id is not null;
  if not claimed then
    return jsonb_build_object('count', jsonb_array_length(files));
  end if;
  return jsonb_build_object('count', jsonb_array_length(files), 'files', files);
end;
$$;
revoke all on function public.case_attachment_summary(text) from public, anon;
grant execute on function public.case_attachment_summary(text) to authenticated;

create or replace function public.view_case_attachment(p_tracking_code text, p_object_key text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sid uuid := public._require_officer();
  r public.reports;
  files jsonb;
  item jsonb;
begin
  if p_object_key is null or btrim(p_object_key) = '' or position('..' in p_object_key) > 0 then
    raise exception 'not found';
  end if;
  select * into r
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
     and station_id = sid
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;
  if r.dispatch_status = 'new' or r.claimed_by_officer_id is null then
    raise exception 'claim required';
  end if;
  files := public._case_attachment_files(r);
  select value into item
    from jsonb_array_elements(files) value
   where value->>'object_key' = p_object_key
   limit 1;
  if item is null then
    raise exception 'not found';
  end if;

  insert into public.report_audit_log (officer_id, report_id, action, detail)
  values (auth.uid(), r.id, 'evidence_viewed', p_object_key);

  return item;
end;
$$;
revoke all on function public.view_case_attachment(text, text) from public, anon;
grant execute on function public.view_case_attachment(text, text) to authenticated;

update storage.buckets
   set public = false
 where id = 'report-photos';

drop policy if exists "officers read own station report photos" on storage.objects;
create policy "officers read claimed photos after audit"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'report-photos'
    and position('..' in name) = 0
    and exists (
      select 1
        from public.reports r
        join public.report_audit_log a on a.report_id = r.id
       where r.tracking_code = split_part(name, '/', 1)
         and r.station_id = public.officer_station_id()
         and r.status <> 'draft'
         and r.dispatch_status is distinct from 'new'
         and r.claimed_by_officer_id is not null
         and a.officer_id = auth.uid()
         and a.action = 'evidence_viewed'
         and a.detail = name
         and a.created_at > now() - interval '5 minutes'
    )
  );
