-- Internal officer notes. Survivors cannot read this table.
-- Writes go through add_case_note. Reads go through list_case_notes.
-- Direct table access stays revoked.

create table public.officer_case_notes (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete cascade,
  officer_id uuid not null references public.officers (id),
  note text not null check (char_length(btrim(note)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index officer_case_notes_report_idx on public.officer_case_notes (report_id, created_at);

alter table public.officer_case_notes enable row level security;

revoke all on table public.officer_case_notes from public, anon, authenticated;

-- Previous check is 20261104190000_case_messages.sql (that list plus 'reply').
-- This list is that list plus 'note'.
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
      'note'
    )
  );

create or replace function public.add_case_note(p_tracking_code text, p_note text)
returns uuid
language plpgsql
security definer
set search_path = public
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
  if not allowed then
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
set search_path = public
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
