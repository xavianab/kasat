import { dispatchDeskStatus, type DeskStatus } from "@/lib/desk";
import { getSupabaseBrowserClient } from "@/lib/supabase";
import type { Incident, IncidentStatus } from "@/lib/types";

export type LiveAccessEvent = {
  id: string;
  at: string;
  actor: string;
  trackingId: string;
  action: "claim" | "resolve" | "location_view" | "create" | "reply" | "status" | "note" | "reopen" | "evidence";
  detail: string;
};

export type OfficerSession = {
  id: string;
  name: string;
  email: string;
  stationId: string;
  stationName: string;
  stationCode: string;
  stationRegion: string;
  generalArea: string;
  spaceAdmin: boolean;
};

/** Prefer the station's name. Use its code when the name is blank. */
export function stationLabel(station: { name?: string | null; code?: string | null }) {
  const name = station.name?.trim() ?? "";
  if (name) return name;
  return station.code?.trim() ?? "";
}

export type ServerReport = {
  id: string;
  tracking_code: string;
  incident_type: string | null;
  approx_location: string | null;
  description: string | null;
  status: string | null;
  dispatch_status: string | null;
  claimed_by_officer_id: string | null;
  claimed_by_name: string | null;
  claimed_at: string | null;
  en_route_at: string | null;
  on_scene_at: string | null;
  resolved_at: string | null;
  sent_at: string | null;
  created_at: string | null;
  is_emergency: boolean | null;
  live_latitude?: number | null;
  live_longitude?: number | null;
};

export type ServerNote = {
  id: string;
  note: string;
  created_at: string;
  officer_name: string | null;
};

export function deskToDispatch(status: DeskStatus): "claimed" | "en_route" | "on_scene" | "resolved" | null {
  if (status === "claimed" || status === "en_route" || status === "on_scene" || status === "resolved") return status;
  return null;
}

function placeFromApprox(text: string | null) {
  const approx = text?.trim() ?? "";
  const subCity = approx.match(/^([^,]+?)\s+sub-city/i)?.[1]?.trim() ?? null;
  const woreda = approx.match(/woreda\s+[^,]+/i)?.[0]?.trim() ?? null;
  const parts = approx.split(",").map((part) => part.trim()).filter(Boolean);
  const landmark = parts.length >= 3 ? parts.slice(2).join(", ") : null;
  return { approx, subCity, woreda, landmark };
}

function hasRealCoordinates(latitude: number, longitude: number) {
  return !(latitude === 0 && longitude === 0) && Number.isFinite(latitude) && Number.isFinite(longitude);
}

export function reportToIncident(row: ServerReport, includeCoordinates: boolean): Incident {
  const place = placeFromApprox(row.approx_location);
  const latitude = includeCoordinates && row.live_latitude != null ? Number(row.live_latitude) : 0;
  const longitude = includeCoordinates && row.live_longitude != null ? Number(row.live_longitude) : 0;
  const submitted = row.sent_at || row.created_at || new Date().toISOString();
  const wire: IncidentStatus =
    row.status === "resolved" || row.dispatch_status === "resolved"
      ? "RESOLVED"
      : row.status === "under_review"
        ? "UNDER_INVESTIGATION"
        : "RECEIVED";
  const actor = row.claimed_by_name || "Officer";
  const history: Incident["history"] = [{ status: "RECEIVED", at: submitted, actor: "INTAKE", note: null }];
  if (row.claimed_at) history.push({ status: "RECEIVED", at: row.claimed_at, actor, note: "Claimed" });
  if (row.en_route_at) history.push({ status: "UNDER_INVESTIGATION", at: row.en_route_at, actor, note: "en_route" });
  if (row.on_scene_at) history.push({ status: "UNDER_INVESTIGATION", at: row.on_scene_at, actor, note: "on_scene" });
  if (row.resolved_at) history.push({ status: "RESOLVED", at: row.resolved_at, actor, note: null });
  return {
    trackingId: row.tracking_code,
    reportId: row.id,
    category: "HRSMT",
    incidentType: row.incident_type,
    description: row.description ?? "",
    priority: row.is_emergency ? "P1" : "P3",
    status: wire,
    countryCode: "ET",
    submittedAt: submitted,
    updatedAt: row.resolved_at || row.on_scene_at || row.en_route_at || row.claimed_at || submitted,
    history,
    location: place.approx
      ? {
          latitude: hasRealCoordinates(latitude, longitude) ? latitude : 0,
          longitude: hasRealCoordinates(latitude, longitude) ? longitude : 0,
          precision: "DISTRICT",
          note: place.approx,
          subCity: place.subCity,
          woreda: place.woreda,
          landmark: place.landmark,
        }
      : null,
    attachments: [],
    assignedStation: row.claimed_by_officer_id,
    assigneeName: row.claimed_by_name,
  };
}

export function phasesFor(rows: ServerReport[]): Record<string, DeskStatus> {
  return Object.fromEntries(rows.map((row) => [row.tracking_code, dispatchDeskStatus(row.dispatch_status)]));
}

export function mergeReports(rows: ServerReport[], previous: Incident[]) {
  const prev = new Map(previous.map((item) => [item.trackingId, item]));
  const incidents = rows.map((row) => {
    const include = row.live_latitude != null && row.live_longitude != null;
    const next = reportToIncident(row, include);
    const old = prev.get(row.tracking_code);
    if (old?.location && next.location && old.location.latitude !== 0 && next.location.latitude === 0) {
      next.location = { ...next.location, latitude: old.location.latitude, longitude: old.location.longitude };
    }
    return next;
  });
  return { incidents, phases: phasesFor(rows) };
}

export async function fetchOfficerSession(): Promise<OfficerSession> {
  const supabase = getSupabaseBrowserClient();
  const { data, error } = await supabase.rpc("current_officer_profile");
  if (error) throw error;
  const row = data as {
    id: string;
    name: string;
    email: string;
    isSpaceAdmin?: boolean;
    station: {
      id: string;
      name: string | null;
      code: string | null;
      region: string | null;
      generalArea: string | null;
    };
  };
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    stationId: row.station.id,
    stationName: stationLabel(row.station),
    stationCode: row.station.code?.trim() ?? "",
    stationRegion: row.station.region?.trim() ?? "",
    generalArea: row.station.generalArea?.trim() ?? "",
    spaceAdmin: row.isSpaceAdmin === true,
  };
}

export async function fetchStationReports(): Promise<ServerReport[]> {
  const supabase = getSupabaseBrowserClient();
  const { data, error } = await supabase.rpc("list_station_reports");
  if (error) throw error;
  return (data ?? []) as ServerReport[];
}

export async function transitionDispatch(trackingId: string, next: string): Promise<ServerReport> {
  const supabase = getSupabaseBrowserClient();
  const { data, error } = await supabase.rpc("transition_report_dispatch", {
    p_tracking_code: trackingId,
    p_next_status: next,
  });
  if (error) throw error;
  return data as ServerReport;
}

export type RevealedIdentity = {
  revealed: boolean;
  fullName: string | null;
  contactChannel: string | null;
  contactHandle: string | null;
  safeNote: string | null;
};

export async function fetchRevealedIdentity(trackingId: string): Promise<RevealedIdentity> {
  const supabase = getSupabaseBrowserClient();
  const { data, error } = await supabase.rpc("get_revealed_identity", { p_tracking_code: trackingId });
  if (error) throw error;
  const row = (data ?? {}) as {
    revealed?: boolean;
    full_name?: string | null;
    contact_channel?: string | null;
    contact_handle?: string | null;
    safe_note?: string | null;
  };
  return {
    revealed: row.revealed === true,
    fullName: row.full_name?.trim() || null,
    contactChannel: row.contact_channel?.trim() || null,
    contactHandle: row.contact_handle?.trim() || null,
    safeNote: row.safe_note?.trim() || null,
  };
}

export async function fetchSensitiveReport(trackingId: string): Promise<ServerReport> {
  const supabase = getSupabaseBrowserClient();
  const { data, error } = await supabase.rpc("get_report_sensitive", { p_tracking_code: trackingId });
  if (error) throw error;
  return data as ServerReport;
}

export async function saveCaseNote(trackingId: string, body: string) {
  const supabase = getSupabaseBrowserClient();
  const { error } = await supabase.rpc("add_case_note", { p_tracking_code: trackingId, p_note: body });
  if (error) throw error;
}

export async function fetchCaseNotes(trackingId: string): Promise<ServerNote[]> {
  const supabase = getSupabaseBrowserClient();
  const { data, error } = await supabase.rpc("list_case_notes", { p_tracking_code: trackingId });
  if (error) throw error;
  return (data ?? []) as ServerNote[];
}

function auditAction(action: string): LiveAccessEvent["action"] {
  if (action === "dispatch_claimed") return "claim";
  if (action === "location_unlock") return "location_view";
  if (action === "reply") return "reply";
  if (action === "note") return "note";
  if (action === "dispatch_resolved") return "resolve";
  if (action === "reopened") return "reopen";
  if (action === "evidence_viewed") return "evidence";
  return "status";
}

export async function fetchAccessLog(incidents: Incident[]): Promise<LiveAccessEvent[]> {
  const supabase = getSupabaseBrowserClient();
  const [{ data, error }, officers] = await Promise.all([
    supabase.from("report_audit_log").select("id, action, detail, created_at, officer_id, report_id").order("created_at", { ascending: true }),
    supabase.from("officers").select("id, name"),
  ]);
  if (error) throw error;
  const tracking = new Map(incidents.filter((item) => item.reportId).map((item) => [item.reportId as string, item.trackingId]));
  const names = new Map(((officers.data ?? []) as { id: string; name: string }[]).map((row) => [row.id, row.name]));
  return ((data ?? []) as { id: string; action: string; detail: string | null; created_at: string; officer_id: string | null; report_id: string }[]).map(
    (row) => ({
      id: row.id,
      at: row.created_at,
      actor: (row.officer_id && names.get(row.officer_id)) || "Officer",
      trackingId: tracking.get(row.report_id) ?? row.report_id,
      action: auditAction(row.action),
      detail: row.action === "reopened" ? (row.detail ?? "reopened") : row.action,
    }),
  );
}

export type CaseFile = {
  objectKey: string;
  integrityStatus: string | null;
  evidenceSha256: string | null;
};

export async function fetchAttachmentSummary(trackingId: string): Promise<{ count: number; files: CaseFile[] | null }> {
  const supabase = getSupabaseBrowserClient();
  const { data, error } = await supabase.rpc("case_attachment_summary", { p_tracking_code: trackingId });
  if (error) throw error;
  const row = (data ?? {}) as {
    count?: number;
    files?: { object_key?: string; integrity_status?: string | null; evidence_sha256?: string | null }[] | null;
  };
  return {
    count: Number(row.count ?? 0),
    files: Array.isArray(row.files)
      ? row.files
          .filter((file) => typeof file.object_key === "string" && file.object_key.length > 0)
          .map((file) => ({
            objectKey: file.object_key as string,
            integrityStatus: file.integrity_status ?? null,
            evidenceSha256: file.evidence_sha256 ?? null,
          }))
      : null,
  };
}

export async function viewCaseAttachment(trackingId: string, objectKey: string): Promise<void> {
  const supabase = getSupabaseBrowserClient();
  const { error } = await supabase.rpc("view_case_attachment", {
    p_tracking_code: trackingId,
    p_object_key: objectKey,
  });
  if (error) throw error;
}

export async function signedAttachmentUrl(objectKey: string): Promise<string> {
  const supabase = getSupabaseBrowserClient();
  const { data, error } = await supabase.storage.from("report-photos").createSignedUrl(objectKey, 300);
  if (error || !data?.signedUrl) throw error ?? new Error("signed url missing");
  return data.signedUrl;
}

export async function reopenCase(trackingId: string, reason: string): Promise<ServerReport> {
  const supabase = getSupabaseBrowserClient();
  const { data, error } = await supabase.rpc("reopen_case", {
    p_tracking_code: trackingId,
    p_reason: reason,
  });
  if (error) throw error;
  return data as ServerReport;
}
