-- Soft flood signal for emergency alerts. Never rejects an alert for a global
-- reason: a blocked real emergency is worse than spam. Per-device limits stay
-- inside trigger_or_coalesce_emergency; per-IP limits stay best-effort only.

-- Constraint must include every event_type already written by earlier
-- migrations (coalesced, rejected_device_cap, rejected_ip_cap) plus the new
-- soft-signal types, so applying this to a DB with existing rows cannot fail.
alter table public.emergency_rate_limit_events
  drop constraint if exists emergency_rate_limit_events_event_type_check;

alter table public.emergency_rate_limit_events
  add constraint emergency_rate_limit_events_event_type_check
  check (event_type in (
    'coalesced',
    'rejected_device_cap',
    'rejected_ip_cap',
    'missing_ip',
    'global_seen',
    'flood_suspected'
  ));

-- Runs on every emergency Edge request (IP present or not). Records one
-- 'global_seen' or 'flood_suspected' event per call. Never blocks the alert.
create or replace function public.check_emergency_global_cap()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  delete from public.emergency_rate_limit_events
   where created_at < now() - interval '24 hours';

  select count(*) into v_count
    from public.emergency_rate_limit_events e
   where e.created_at >= now() - interval '10 minutes'
     and e.event_type in ('global_seen', 'flood_suspected');

  if v_count > 30 then
    insert into public.emergency_rate_limit_events (event_type)
    values ('flood_suspected');
    return 'flood_suspected';
  end if;

  insert into public.emergency_rate_limit_events (event_type)
  values ('global_seen');
  return 'allowed';
end;
$$;

revoke all on function public.check_emergency_global_cap() from public, anon, authenticated;
grant execute on function public.check_emergency_global_cap() to service_role;
