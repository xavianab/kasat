-- Revealed name and phone belong only to the claiming officer.
-- A null claimant is not a match: NULL = officer id is unknown, and
-- "if not unknown" does not deny access. Require allowed is true.

create or replace function public.get_revealed_identity(p_tracking_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
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

  -- Equality is unknown when the case is unclaimed, so this stays false
  -- for every officer until one of them is the claimant.
  if r.claimed_by_officer_id = auth.uid() is not true then
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
