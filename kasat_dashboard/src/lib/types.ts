/**
 * Wire contract shared with the Flutter client.
 *
 * These codes are the literal strings persisted by `kasat_mobile`
 * (`lib/models/*.dart`). Changing one here without changing it there silently
 * breaks triage, so treat this file as the schema of record for both apps.
 */

export const INCIDENT_STATUSES = ["RECEIVED", "UNDER_INVESTIGATION", "RESOLVED"] as const;
export type IncidentStatus = (typeof INCIDENT_STATUSES)[number];

export const PRIORITIES = ["P1", "P2", "P3", "P4"] as const;
export type Priority = (typeof PRIORITIES)[number];

export const CATEGORIES = ["HRSMT", "ASSLT", "FRAUD", "TRFCK", "CRRPT", "CRTCL"] as const;
export type CategoryCode = (typeof CATEGORIES)[number];

export const STATUS_LABELS: Record<IncidentStatus, string> = {
  RECEIVED: "Received",
  UNDER_INVESTIGATION: "Under Investigation",
  RESOLVED: "Resolved",
};

export const PRIORITY_LABELS: Record<Priority, string> = {
  P1: "Critical",
  P2: "High",
  P3: "Medium",
  P4: "Low",
};

export const CATEGORY_LABELS: Record<CategoryCode, string> = {
  HRSMT: "Harassment",
  ASSLT: "Physical Assault",
  FRAUD: "Fraud",
  TRFCK: "Trafficking",
  CRRPT: "Abuse of Power",
  CRTCL: "Critical Emergency",
};

export interface Attachment {
  id: string;
  label: string;
  mimeType: string;
  byteSize: number;
  storagePath: string;
  strippedMetadata: boolean;
  width: number | null;
  height: number | null;
}

export interface ApproxLocation {
  latitude: number;
  longitude: number;
  precision: "BLOCK" | "DISTRICT" | "CITY" | "REGION";
  note: string | null;
}

export interface StatusEvent {
  status: IncidentStatus;
  at: string;
  actor: string;
  note: string | null;
}

export const COUNTRIES = ["ET", "US"] as const;
export type CountryCode = string;

export const COUNTRY_LABELS: Record<string, string> = {
  ET: "Ethiopia",
  US: "United States",
};

export interface Incident {
  trackingId: string;
  category: CategoryCode;
  description: string;
  priority: Priority;
  status: IncidentStatus;
  /** ISO 3166-1 alpha-2 chosen at onboarding. Used to filter and route. */
  countryCode: CountryCode;
  submittedAt: string;
  updatedAt: string;
  history: StatusEvent[];
  location: ApproxLocation | null;
  attachments: Attachment[];
  assignedStation: string | null;
}

export interface DispatchMetrics {
  total: number;
  pending: number;
  investigating: number;
  resolved: number;
  /** Median minutes from submission to first status change. */
  medianResponseMinutes: number | null;
}

export function computeMetrics(incidents: Incident[]): DispatchMetrics {
  const firstResponses = incidents
    .map((incident) => {
      const claim = incident.history.find((e) => e.status !== "RECEIVED");
      if (!claim) return null;
      const delta = Date.parse(claim.at) - Date.parse(incident.submittedAt);
      return Number.isFinite(delta) ? delta / 60_000 : null;
    })
    .filter((v): v is number => v !== null)
    .sort((a, b) => a - b);

  const median =
    firstResponses.length === 0
      ? null
      : firstResponses[Math.floor(firstResponses.length / 2)];

  return {
    total: incidents.length,
    pending: incidents.filter((i) => i.status === "RECEIVED").length,
    investigating: incidents.filter((i) => i.status === "UNDER_INVESTIGATION").length,
    resolved: incidents.filter((i) => i.status === "RESOLVED").length,
    medianResponseMinutes: median === undefined ? null : median,
  };
}
