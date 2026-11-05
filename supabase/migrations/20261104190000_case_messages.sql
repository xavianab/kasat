-- Officer and survivor messages for one case.
-- Internal desk notes are not stored here, so a survivor never sees them.
-- There is no earlier messages table or Edge Function for officer replies.
-- Direct table access is denied. Reads and writes go through the functions below.

alter table public.officers
  add column if not exists is_space_admin boolean not null default false;

-- authenticated has SELECT only (see 20261029140000_security_hardening.sql).
-- Revoke the column anyway so a later table-wide UPDATE grant does not include it.
revoke update (is_space_admin) on table public.officers from public, anon, authenticated;

create or replace function public.officers_protect_space_admin()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if coalesce(new.is_space_admin, false)
       and coalesce(auth.role(), '') is distinct from 'service_role' then
      raise exception 'is_space_admin can only be set by the service role';
    end if;
  elsif new.is_space_admin is distinct from old.is_space_admin
        and coalesce(auth.role(), '') is distinct from 'service_role' then
    raise exception 'is_space_admin can only be set by the service role';
  end if;
  return new;
end;
$$;

revoke all on function public.officers_protect_space_admin() from public, anon, authenticated;

drop trigger if exists officers_protect_space_admin on public.officers;
create trigger officers_protect_space_admin
  before insert or update on public.officers
  for each row
  execute function public.officers_protect_space_admin();

create table public.case_messages (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.reports (id) on delete cascade,
  sender text not null check (sender in ('officer', 'survivor')),
  officer_id uuid references public.officers (id),
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  constraint case_messages_sender_shape check (
    (sender = 'officer' and officer_id is not null)
    or (sender = 'survivor' and officer_id is null)
  )
);

create index case_messages_case_idx on public.case_messages (case_id, created_at);

alter table public.case_messages enable row level security;

revoke all on table public.case_messages from public, anon, authenticated;

-- reports.tracking_code is already "text not null unique"
-- (reports_tracking_code_key in 20261019100000_shared_reports.sql).
-- No second unique index is added here.

-- Previous check is 20261029140000_security_hardening.sql.
-- That list already contains 'location_unlock'. This list is that list plus 'reply'.
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
      'reply'
    )
  );

-- Officer reply used by Kasat Desk when Supabase is connected.
create or replace function public.send_officer_reply(p_tracking_code text, p_body text)
returns uuid
language plpgsql
security definer
set search_path = public
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
  if not allowed then
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
set search_path = public
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
  if not allowed then
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

create or replace function public.send_survivor_reply(p_access_secret text, p_body text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.reports;
  mid uuid;
  recent integer;
begin
  if char_length(btrim(coalesce(p_body, ''))) not between 1 and 2000 then
    raise exception 'empty reply';
  end if;
  select * into r
    from public.reports
   where access_secret = p_access_secret
     and status <> 'draft'
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;
  select count(*) into recent
    from public.case_messages m
   where m.case_id = r.id
     and m.created_at > now() - interval '1 hour';
  if recent >= 20 then
    raise exception 'too many messages';
  end if;
  insert into public.case_messages (case_id, sender, officer_id, body)
  values (r.id, 'survivor', null, btrim(p_body))
  returning id into mid;
  return mid;
end;
$$;

revoke all on function public.send_survivor_reply(text, text) from public, authenticated;
grant execute on function public.send_survivor_reply(text, text) to anon;

create or replace function public.list_survivor_replies(p_access_secret text)
returns table (
  sender text,
  body text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select m.sender, m.body, m.created_at
    from public.case_messages m
    join public.reports r on r.id = m.case_id
   where r.access_secret = p_access_secret
     and r.status <> 'draft'
   order by m.created_at;
$$;

revoke all on function public.list_survivor_replies(text) from public, authenticated;
grant execute on function public.list_survivor_replies(text) to anon;
