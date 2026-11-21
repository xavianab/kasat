-- Hard-cap automated replies (Claude or fallback) at 3 per case per hour.
-- Serialize count+insert with an advisory lock so concurrent invokes cannot
-- slip past the check.

create or replace function public.send_automated_reply(
  p_case_id uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  mid uuid;
  recent integer;
begin
  if coalesce(auth.role(), '') is distinct from 'service_role' then
    raise exception 'service role required';
  end if;
  if char_length(btrim(coalesce(p_body, ''))) not between 1 and 2000 then
    raise exception 'empty reply';
  end if;
  select * into r
    from public.reports
   where id = p_case_id
     and status <> 'draft'
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;

  -- One insert at a time per case. Counts every automated row, including fallbacks.
  perform pg_advisory_xact_lock(hashtextextended(r.id::text, 0));

  select count(*) into recent
    from public.case_messages m
   where m.case_id = r.id
     and m.sender = 'automated'
     and m.created_at > now() - interval '1 hour';
  if recent >= 3 then
    raise exception 'automated_rate_limited';
  end if;

  insert into public.case_messages (case_id, sender, officer_id, body)
  values (r.id, 'automated', null, btrim(p_body))
  returning id into mid;
  return mid;
end;
$$;

revoke all on function public.send_automated_reply(uuid, text) from public, anon, authenticated;
grant execute on function public.send_automated_reply(uuid, text) to service_role;
