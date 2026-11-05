-- Survivor progress, and who on the desk may read a revealed identity.
-- Returns no officer name, no coordinates, and no message text.

create table if not exists public.survivor_status_reads (
  secret_hash text primary key,
  window_started timestamptz not null default now(),
  hits integer not null default 0
);

alter table public.survivor_status_reads enable row level security;
revoke all on table public.survivor_status_reads from public, anon, authenticated;

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

create or replace function public.get_revealed_identity(p_tracking_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  allowed boolean := false;
  ri public.report_identities;
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

  if r.identity_revealed is not true then
    return jsonb_build_object('revealed', false);
  end if;

  select
    r.claimed_by_officer_id = auth.uid()
    or exists (
      select 1
        from public.officers o
       where o.id = auth.uid()
         and o.is_space_admin
         and o.station_id is not distinct from r.station_id
    )
    into allowed;

  if not allowed then
    return jsonb_build_object('revealed', true);
  end if;

  select * into ri
    from public.report_identities
   where report_id = r.id
   limit 1;
  if ri.id is null then
    return jsonb_build_object('revealed', true);
  end if;

  return jsonb_build_object(
    'revealed', true,
    'full_name', ri.full_name,
    'contact_channel', ri.contact_channel,
    'contact_handle', ri.contact_handle,
    'safe_note', ri.safe_note,
    'revealed_at', ri.revealed_at
  );
end;
$$;

revoke all on function public.get_revealed_identity(text) from public, anon;
grant execute on function public.get_revealed_identity(text) to authenticated;
