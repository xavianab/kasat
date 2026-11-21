-- AI first responder: allow automated case messages, insert RPC, and
-- async invoke from send_draft_report / send_survivor_reply via pg_net.
--
-- Trigger choice: call the Edge Function from the existing send RPCs
-- (not a table webhook). That way:
--   1) only the report description or message text is posted (never name,
--      phone, location, photo, device id, or case code);
--   2) inserting an automated reply cannot re-trigger the AI.
--
-- Vault secrets (set once on the project, outside this file):
--   project_url                  e.g. https://vbpwhruoyibbivpchmaf.supabase.co
--   first_responder_hook_secret  shared with Edge secret FIRST_RESPONDER_HOOK_SECRET
-- If either is missing, request_first_responder is a no-op.

create extension if not exists pg_net;

-- Allow sender = 'automated' (Kasat support automated replies).
alter table public.case_messages
  drop constraint if exists case_messages_sender_check;
alter table public.case_messages
  add constraint case_messages_sender_check
  check (sender in ('officer', 'survivor', 'automated'));

alter table public.case_messages
  drop constraint if exists case_messages_sender_shape;
alter table public.case_messages
  add constraint case_messages_sender_shape check (
    (sender = 'officer' and officer_id is not null)
    or (sender = 'survivor' and officer_id is null)
    or (sender = 'automated' and officer_id is null)
  );

-- Service-role path used by the first-responder Edge Function.
-- Direct table inserts stay revoked for anon/authenticated.
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
-- PostgREST service_role calls use the service key; grant to postgres is enough
-- for SQL, but Edge Functions call via REST so grant execute to service_role.
grant execute on function public.send_automated_reply(uuid, text) to service_role;

-- Rate-limit probe for the Edge Function (does not insert).
create or replace function public.count_automated_replies_last_hour(p_case_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  if coalesce(auth.role(), '') is distinct from 'service_role' then
    raise exception 'service role required';
  end if;
  select count(*)::integer into n
    from public.case_messages m
   where m.case_id = p_case_id
     and m.sender = 'automated'
     and m.created_at > now() - interval '1 hour';
  return coalesce(n, 0);
end;
$$;

revoke all on function public.count_automated_replies_last_hour(uuid) from public, anon, authenticated;
grant execute on function public.count_automated_replies_last_hour(uuid) to service_role;

-- Fire-and-forget HTTP to the first-responder Edge Function.
-- Posts only case_id + source text. Never posts PII columns.
create or replace function public.request_first_responder(
  p_case_id uuid,
  p_text text,
  p_source text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
  v_body text;
begin
  v_body := btrim(coalesce(p_text, ''));
  if p_case_id is null or char_length(v_body) < 1 then
    return;
  end if;
  if p_source is distinct from 'report' and p_source is distinct from 'message' then
    return;
  end if;

  select decrypted_secret into v_url
    from vault.decrypted_secrets
   where name = 'project_url'
   limit 1;
  select decrypted_secret into v_secret
    from vault.decrypted_secrets
   where name = 'first_responder_hook_secret'
   limit 1;

  if v_url is null or btrim(v_url) = '' or v_secret is null or btrim(v_secret) = '' then
    return;
  end if;

  perform net.http_post(
    url := rtrim(btrim(v_url), '/') || '/functions/v1/first-responder',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-kasat-responder-secret', btrim(v_secret)
    ),
    body := jsonb_build_object(
      'case_id', p_case_id,
      'text', left(v_body, 2000),
      'source', p_source
    ),
    timeout_milliseconds := 2000
  );
exception
  when others then
    -- Never fail the survivor send path if the AI invoke fails.
    return;
end;
$$;

revoke all on function public.request_first_responder(uuid, text, text) from public, anon, authenticated;

-- Officer list: surface automated sender with a fixed display name.
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
set search_path = ''
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
    select
      m.id,
      m.sender,
      m.body,
      m.created_at,
      case
        when m.sender = 'automated' then 'Kasat support (automated)'::text
        else o.name
      end
    from public.case_messages m
    left join public.officers o on o.id = m.officer_id
   where m.case_id = r.id
   order by m.created_at;
end;
$$;

revoke all on function public.list_case_messages(text) from public, anon;
grant execute on function public.list_case_messages(text) to authenticated;

-- Survivor list unchanged shape; automated rows are included via sender.
create or replace function public.list_survivor_replies(p_access_secret text)
returns table (
  sender text,
  body text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
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

create or replace function public.send_survivor_reply(p_access_secret text, p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  mid uuid;
  recent integer;
  v_body text;
begin
  v_body := btrim(coalesce(p_body, ''));
  if char_length(v_body) not between 1 and 2000 then
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
  values (r.id, 'survivor', null, v_body)
  returning id into mid;

  perform public.request_first_responder(r.id, v_body, 'message');

  return mid;
end;
$$;

revoke all on function public.send_survivor_reply(text, text) from public, authenticated;
grant execute on function public.send_survivor_reply(text, text) to anon;

-- Preserve keep-sent-evidence behaviour; invoke AI only on first send.
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
  v_was_draft boolean;
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

  v_was_draft := r.status = 'draft';
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

  if v_was_draft then
    perform public.request_first_responder(r.id, r.description, 'report');
  end if;

  return public._survivor_report_json(r, true);
end;
$$;

revoke all on function public.send_draft_report(text, text, text) from public;
grant execute on function public.send_draft_report(text, text, text) to anon, authenticated;
