-- A retry of a report that is already sent and already has a photo must succeed
-- without replacing that photo, its client hash, or its integrity status.

create or replace function public.send_draft_report(
  p_access_secret text,
  p_photo_url text default null,
  p_client_sha256 text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  v_photo text;
  v_keep_evidence boolean;
begin
  select * into r
    from public.reports
   where access_secret = p_access_secret
   limit 1;
  if r.id is null then
    raise exception 'not found';
  end if;
  if r.status not in ('draft', 'sent') then
    raise exception 'cannot send';
  end if;

  v_keep_evidence := r.status = 'sent'
    and nullif(btrim(coalesce(r.photo_url, '')), '') is not null;

  v_photo := nullif(btrim(coalesce(p_photo_url, '')), '');
  if v_photo is not null and (
    position('..' in v_photo) > 0
    or split_part(v_photo, '/', 1) is distinct from r.tracking_code
  ) then
    v_photo := null;
  end if;

  update public.reports
     set status = 'sent',
         sent_at = coalesce(sent_at, now()),
         photo_url = case
           when v_keep_evidence then photo_url
           else coalesce(v_photo, photo_url)
         end,
         client_evidence_sha256 = case
           when v_keep_evidence then client_evidence_sha256
           else coalesce(
             nullif(lower(btrim(coalesce(p_client_sha256, ''))), ''),
             client_evidence_sha256
           )
         end,
         evidence_integrity_status = case
           when v_keep_evidence then evidence_integrity_status
           when coalesce(v_photo, photo_url) is not null
                and evidence_sha256 is null
             then 'pending_server_hash'
           else evidence_integrity_status
         end
   where id = r.id
   returning * into r;

  return public._survivor_report_json(r, true);
end;
$$;
