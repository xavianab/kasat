-- Officer and survivor messages for one case.
-- Internal desk notes are not stored here, so a survivor never sees them.
-- There is no earlier messages table or Edge Function for officer replies.

alter table public.officers
  add column if not exists is_space_admin boolean not null default false;

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
grant select, insert on table public.case_messages to authenticated;
grant select, insert on table public.case_messages to anon;

create policy "claiming officer and space admins read messages"
  on public.case_messages for select
  to authenticated
  using (
    exists (
      select 1
        from public.reports r
       where r.id = case_messages.case_id
         and r.status <> 'draft'
         and (
           r.claimed_by_officer_id = auth.uid()
           or exists (
             select 1
               from public.officers o
              where o.id = auth.uid()
                and o.is_space_admin
                and o.station_id is not distinct from r.station_id
           )
         )
    )
  );

create policy "claiming officer and space admins write messages"
  on public.case_messages for insert
  to authenticated
  with check (
    sender = 'officer'
    and officer_id = auth.uid()
    and exists (
      select 1
        from public.reports r
       where r.id = case_messages.case_id
         and r.status <> 'draft'
         and (
           r.claimed_by_officer_id = auth.uid()
           or exists (
             select 1
               from public.officers o
              where o.id = auth.uid()
                and o.is_space_admin
                and o.station_id is not distinct from r.station_id
           )
         )
    )
  );

-- The survivor proves the case with the secret already stored on the report.
-- A tracking code alone is not enough.
create policy "survivor reads own case messages"
  on public.case_messages for select
  to anon
  using (
    exists (
      select 1
        from public.reports r
       where r.id = case_messages.case_id
         and r.access_secret is not null
         and r.access_secret = current_setting('request.headers', true)::json ->> 'x-access-secret'
    )
  );

create policy "survivor writes own case messages"
  on public.case_messages for insert
  to anon
  with check (
    sender = 'survivor'
    and officer_id is null
    and exists (
      select 1
        from public.reports r
       where r.id = case_messages.case_id
         and r.status <> 'draft'
         and r.access_secret is not null
         and r.access_secret = current_setting('request.headers', true)::json ->> 'x-access-secret'
    )
  );

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
  if char_length(btrim(coalesce(p_body, ''))) < 1 then
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

create or replace function public.send_survivor_reply(p_access_secret text, p_body text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.reports;
  mid uuid;
begin
  if char_length(btrim(coalesce(p_body, ''))) < 1 then
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
  insert into public.case_messages (case_id, sender, officer_id, body)
  values (r.id, 'survivor', null, btrim(p_body))
  returning id into mid;
  return mid;
end;
$$;

revoke all on function public.send_survivor_reply(text, text) from public, authenticated;
grant execute on function public.send_survivor_reply(text, text) to anon;

create or replace function public.list_survivor_replies(p_access_secret text)
returns setof public.case_messages
language sql
stable
security definer
set search_path = public
as $$
  select m.*
    from public.case_messages m
    join public.reports r on r.id = m.case_id
   where r.access_secret = p_access_secret
     and r.status <> 'draft'
   order by m.created_at;
$$;

revoke all on function public.list_survivor_replies(text) from public, authenticated;
grant execute on function public.list_survivor_replies(text) to anon;
