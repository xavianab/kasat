-- Evidence details belong to the claiming officer.
-- Before a claim, and for every other officer after a claim, the
-- attachment functions return a count only. Direct column reads of
-- the path and hashes are revoked. The queue JSON no longer carries them.

revoke select (
  photo_url,
  evidence_sha256,
  client_evidence_sha256,
  evidence_integrity_status,
  evidence_verified_at
) on table public.reports from authenticated;

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
    'identity_revealed', r.identity_revealed
  );
$$;
revoke all on function public._officer_report_json(public.reports, boolean) from public, anon, authenticated;

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
  if r.claimed_by_officer_id = auth.uid() is not true then
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
  if r.claimed_by_officer_id = auth.uid() is not true then
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

drop policy if exists "officers read claimed photos after audit" on storage.objects;
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
         and r.claimed_by_officer_id = auth.uid()
         and a.officer_id = auth.uid()
         and a.action = 'evidence_viewed'
         and a.detail = name
         and a.created_at > now() - interval '5 minutes'
    )
  );

-- The old policy is dropped even when the bucket is absent, so a leftover
-- station-wide read cannot survive. The replacement is created only when
-- the bucket is already there, which is a no-op on a fresh install.
drop policy if exists "officers read own station incident evidence" on storage.objects;
do $$
begin
  if exists (select 1 from storage.buckets where id = 'incident-evidence') then
    execute $policy$
      create policy "officers read own station incident evidence"
        on storage.objects for select to authenticated
        using (
          bucket_id = 'incident-evidence'
          and position('..' in name) = 0
          and exists (
            select 1
              from public.reports r
              join public.report_audit_log a on a.report_id = r.id
             where r.tracking_code = split_part(name, '/', 1)
               and r.station_id = public.officer_station_id()
               and r.status <> 'draft'
               and r.claimed_by_officer_id = auth.uid()
               and a.officer_id = auth.uid()
               and a.action = 'evidence_viewed'
               and a.detail = name
               and a.created_at > now() - interval '5 minutes'
          )
        )
    $policy$;
  end if;
end $$;

create or replace function public.add_case_note(p_tracking_code text, p_note text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  nid uuid;
  allowed boolean;
begin
  if auth.uid() is null then
    raise exception 'not an officer';
  end if;
  if char_length(btrim(coalesce(p_note, ''))) not between 1 and 2000 then
    raise exception 'empty note';
  end if;
  select * into r
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;
  select
    r.claimed_by_officer_id = auth.uid()
    or exists (
      select 1 from public.officers o
       where o.id = auth.uid()
         and o.is_space_admin
         and o.station_id is not distinct from r.station_id
    )
    into allowed;
  if allowed is not true then
    raise exception 'claim required';
  end if;
  insert into public.officer_case_notes (report_id, officer_id, note)
  values (r.id, auth.uid(), btrim(p_note))
  returning id into nid;
  insert into public.report_audit_log (officer_id, report_id, action)
  values (auth.uid(), r.id, 'note');
  return nid;
end;
$$;
revoke all on function public.add_case_note(text, text) from public, anon;
grant execute on function public.add_case_note(text, text) to authenticated;

create or replace function public.send_officer_reply(p_tracking_code text, p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  mid uuid;
  allowed boolean;
begin
  if auth.uid() is null then
    raise exception 'not an officer';
  end if;
  if char_length(btrim(coalesce(p_body, ''))) not between 1 and 2000 then
    raise exception 'empty reply';
  end if;
  select * into r
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;
  select
    r.claimed_by_officer_id = auth.uid()
    or exists (
      select 1 from public.officers o
       where o.id = auth.uid()
         and o.is_space_admin
         and o.station_id is not distinct from r.station_id
    )
    into allowed;
  if allowed is not true then
    raise exception 'claim required';
  end if;
  insert into public.case_messages (case_id, sender, officer_id, body)
  values (r.id, 'officer', auth.uid(), btrim(p_body))
  returning id into mid;
  insert into public.report_audit_log (officer_id, report_id, action)
  values (auth.uid(), r.id, 'reply');
  return mid;
end;
$$;
revoke all on function public.send_officer_reply(text, text) from public, anon;
grant execute on function public.send_officer_reply(text, text) to authenticated;

create or replace function public.list_case_messages(p_tracking_code text)
returns table (
  id uuid,
  sender text,
  body text,
  created_at timestamptz,
  officer_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r public.reports;
  allowed boolean;
begin
  if auth.uid() is null then
    raise exception 'not an officer';
  end if;
  select * into r
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;
  select
    r.claimed_by_officer_id = auth.uid()
    or exists (
      select 1 from public.officers o
       where o.id = auth.uid()
         and o.is_space_admin
         and o.station_id is not distinct from r.station_id
    )
    into allowed;
  if allowed is not true then
    raise exception 'claim required';
  end if;
  return query
    select m.id, m.sender, m.body, m.created_at, o.name
      from public.case_messages m
      left join public.officers o on o.id = m.officer_id
     where m.case_id = r.id
     order by m.created_at;
end;
$$;
revoke all on function public.list_case_messages(text) from public, anon;
grant execute on function public.list_case_messages(text) to authenticated;

create or replace function public.list_case_notes(p_tracking_code text)
returns table (
  id uuid,
  note text,
  created_at timestamptz,
  officer_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r public.reports;
begin
  if auth.uid() is null then
    raise exception 'not an officer';
  end if;
  select * into r
    from public.reports
   where tracking_code = p_tracking_code
     and status <> 'draft'
     and station_id = public.officer_station_id()
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;
  return query
    select n.id, n.note, n.created_at, o.name
      from public.officer_case_notes n
      left join public.officers o on o.id = n.officer_id
     where n.report_id = r.id
     order by n.created_at;
end;
$$;
revoke all on function public.list_case_notes(text) from public, anon;
grant execute on function public.list_case_notes(text) to authenticated;

create or replace function public.get_my_case_status(p_access_secret text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  v_hash text;
  v_hits integer;
begin
  delete from public.survivor_status_reads
   where window_started < now() - interval '1 day';

  if p_access_secret is null or btrim(p_access_secret) = '' then
    raise exception 'not found';
  end if;

  v_hash := public._kasat_hmac('status:' || p_access_secret);
  if v_hash is null then
    raise exception 'not found';
  end if;

  insert into public.survivor_status_reads (secret_hash, window_started, hits)
  values (v_hash, now(), 1)
  on conflict (secret_hash) do update
    set hits = case
          when public.survivor_status_reads.window_started < now() - interval '1 minute' then 1
          else public.survivor_status_reads.hits + 1
        end,
        window_started = case
          when public.survivor_status_reads.window_started < now() - interval '1 minute' then now()
          else public.survivor_status_reads.window_started
        end
  returning hits into v_hits;

  if v_hits > 30 then
    raise exception 'too many requests';
  end if;

  select * into r
    from public.reports
   where access_secret = p_access_secret
     and status <> 'draft'
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;

  return jsonb_build_object(
    'status', r.status,
    'dispatch_status', r.dispatch_status,
    'sent_at', r.sent_at,
    'claimed_at', r.claimed_at,
    'en_route_at', r.en_route_at,
    'on_scene_at', r.on_scene_at,
    'resolved_at', r.resolved_at,
    'reopened', r.resolved_at is not null
      and r.dispatch_status is distinct from 'resolved'
  );
end;
$$;
revoke all on function public.get_my_case_status(text) from public, authenticated;
grant execute on function public.get_my_case_status(text) to anon;

notify pgrst, 'reload schema';
