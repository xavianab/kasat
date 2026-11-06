-- A later send cannot store a photo key that belongs to another report.
-- Attachment listing only includes files stored under this report's tracking code.
-- Opening a file still requires the claiming officer plus a fresh evidence_viewed audit row.

create or replace function public._case_attachment_files(r public.reports)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  files jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
           'object_key', s.name,
           'integrity_status', case
             when s.name = r.photo_url then r.evidence_integrity_status::text
             else null
           end,
           'evidence_sha256', case
             when s.name = r.photo_url then r.evidence_sha256
             else null
           end
         ) order by s.name), '[]'::jsonb)
    into files
    from storage.objects s
   where s.bucket_id = 'report-photos'
     and split_part(s.name, '/', 1) = r.tracking_code
     and position('..' in s.name) = 0;
  return files;
end;
$$;

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
         photo_url = coalesce(v_photo, photo_url),
         client_evidence_sha256 = coalesce(
           nullif(lower(btrim(coalesce(p_client_sha256, ''))), ''),
           client_evidence_sha256
         ),
         evidence_integrity_status = case
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
