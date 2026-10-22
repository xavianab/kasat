-- Ensure `extensions` is in search_path for `digest()` (pgcrypto) and reload PostgREST schema cache

alter function public.compute_request_fingerprints(double precision, double precision)
  set search_path = public, extensions;

alter function public.trigger_or_coalesce_emergency(text, text, text, boolean, double precision, double precision, double precision, text)
  set search_path = public, extensions;

alter function public.transition_report_dispatch(text, text, text, text)
  set search_path = public, extensions;

alter function public.record_sla_escalation(text, text, text)
  set search_path = public, extensions;

notify pgrst, 'reload schema';
