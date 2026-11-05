-- An unclaimed case has no claimant. Comparing that null id to the
-- signed-in officer is unknown, not false, so the name was returned to
-- every officer at the station. Require an explicit true.

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
