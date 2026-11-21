-- Rate limits for the community-alert review proxy (service_role only).
-- The Edge Function passes a client-derived caller id (never the raw device
-- secret). This RPC stores only _kasat_hmac of that id — the received value
-- is never written to the table.
-- Cap cases RETURN a status string (after inserting the rejection row) so the
-- insert is committed; only invalid_caller raises.

create table if not exists public.ai_proxy_rate_limit_events (
  id uuid primary key default gen_random_uuid(),
  caller_hash text not null,
  event_type text not null
    check (event_type in ('allowed', 'rejected_caller_cap', 'rejected_global_cap')),
  created_at timestamptz not null default now()
);

create index if not exists ai_proxy_rate_limit_events_caller_created_idx
  on public.ai_proxy_rate_limit_events (caller_hash, created_at desc);

create index if not exists ai_proxy_rate_limit_events_created_idx
  on public.ai_proxy_rate_limit_events (created_at desc);

alter table public.ai_proxy_rate_limit_events enable row level security;
revoke all on table public.ai_proxy_rate_limit_events from public, anon, authenticated;
-- No policies for anon or authenticated: only service_role (bypasses RLS) writes.

create or replace function public.check_ai_proxy_caller_limit(p_caller_id text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hash text;
  v_caller_count integer;
  v_global_count integer;
begin
  if p_caller_id is null or char_length(btrim(p_caller_id)) < 32 then
    raise exception 'invalid_caller';
  end if;

  -- Keep the table bounded: drop events older than a day before counting.
  delete from public.ai_proxy_rate_limit_events
   where created_at < now() - interval '24 hours';

  -- Store only a server-side hash of the received caller_id, never the value itself.
  v_hash := public._kasat_hmac('ai-proxy:' || btrim(p_caller_id));

  select count(*) into v_caller_count
    from public.ai_proxy_rate_limit_events e
   where e.caller_hash = v_hash
     and e.created_at >= now() - interval '10 minutes';

  if v_caller_count >= 20 then
    insert into public.ai_proxy_rate_limit_events (caller_hash, event_type)
    values (v_hash, 'rejected_caller_cap');
    return 'caller_cap';
  end if;

  select count(*) into v_global_count
    from public.ai_proxy_rate_limit_events e
   where e.created_at >= now() - interval '10 minutes'
     and e.event_type = 'allowed';

  if v_global_count >= 200 then
    insert into public.ai_proxy_rate_limit_events (caller_hash, event_type)
    values (v_hash, 'rejected_global_cap');
    return 'global_cap';
  end if;

  insert into public.ai_proxy_rate_limit_events (caller_hash, event_type)
  values (v_hash, 'allowed');
  return 'allowed';
end;
$$;

revoke all on function public.check_ai_proxy_caller_limit(text) from public, anon, authenticated;
grant execute on function public.check_ai_proxy_caller_limit(text) to service_role;
