import type { Messages } from "./messages";
import { claimedPlace, publicPlace } from "./places";

export { publicPlace };
import { fill } from "./utils";
import type { CategoryCode, Incident, IncidentStatus, Priority } from "./types";

export const OPERATOR = {
  id: "desk-officer",
  name: "Station officer",
  email: "officer@bole-station.example",
  org: "Kasat",
  initials: "SO",
  role: "space_admin" as const,
};

export type SpaceType = "police" | "ngo" | "shelter" | "health" | "legal";
export type SpaceIcon = "station" | "shield" | "heart" | "scale" | "home";

export type SpaceDetails = {
  icon: SpaceIcon;
  name: string;
  key: string;
  type: SpaceType;
  region: string;
  description: string;
  lead: string;
  defaultAssignee: string;
};

export const DEFAULT_SPACE: SpaceDetails = {
  icon: "station",
  name: "Bole Sub-City Station",
  key: "ADD",
  type: "police",
  region: "Addis Ababa",
  description: "Police space for Bole Sub-City.",
  lead: OPERATOR.name,
  defaultAssignee: OPERATOR.name,
};

export type DeskStatus =
  | "new"
  | "claimed"
  | "en_route"
  | "on_scene"
  | "progress"
  | "waiting"
  | "escalated"
  | "referred"
  | "resolved"
  | "closed";

/** dispatch_status values that exist on reports. Unknown values stay New. */
export function dispatchDeskStatus(dispatch: string | null | undefined): DeskStatus {
  if (dispatch === "claimed") return "claimed";
  if (dispatch === "en_route") return "en_route";
  if (dispatch === "on_scene") return "on_scene";
  if (dispatch === "resolved") return "resolved";
  return "new";
}

export const INITIAL_PHASES: Record<string, DeskStatus> = {
  "KST-8X9P2": "new",
  "KST-4RT7Q": "new",
  "KST-3HM6N": "progress",
  "KST-7CK2L": "progress",
  "KST-5WP8D": "waiting",
  "KST-9WM2K": "resolved",
};

/** Statuses an officer may move to. Only values transition_report_dispatch saves. */
export function allowedStatusMoves(status: DeskStatus): DeskStatus[] {
  if (status === "new") return ["claimed"];
  if (status === "claimed" || status === "progress") return ["en_route", "on_scene", "resolved"];
  if (status === "en_route") return ["on_scene", "resolved"];
  if (status === "on_scene") return ["resolved"];
  return [];
}

export type QueueId = "unclaimed" | "mine" | "open" | "waiting" | "resolved";

export const QUEUE_IDS: QueueId[] = ["unclaimed", "mine", "open", "waiting", "resolved"];

export function isQueueId(value: string): value is QueueId {
  return (QUEUE_IDS as string[]).includes(value);
}

/** Tier 1 until an officer has claimed the case. */
export function isUnclaimed(incident: Incident) {
  return incident.status === "RECEIVED" && !incident.assignedStation;
}

export const DESK_CATEGORIES = ["sexual", "domestic", "marriage", "child", "harassment", "other"] as const;
export type DeskCategory = (typeof DESK_CATEGORIES)[number];

/** Desk-only labels for the local sample queue. Not a database field. */
const SAMPLE_DESK: Record<string, { category: DeskCategory; waiting?: boolean }> = {
  "KST-8X9P2": { category: "sexual" },
  "KST-4RT7Q": { category: "marriage" },
  "KST-3HM6N": { category: "domestic" },
  "KST-7CK2L": { category: "child" },
  "KST-5WP8D": { category: "harassment", waiting: true },
  "KST-9WM2K": { category: "other" },
};

const DESK_CATEGORY_KEY: Record<DeskCategory, keyof Messages> = {
  sexual: "catSexual",
  domestic: "catDomestic",
  marriage: "catMarriage",
  child: "catChild",
  harassment: "catHarassment",
  other: "catOther",
};

export function sampleCategory(incident: Incident): DeskCategory | null {
  return SAMPLE_DESK[incident.trackingId]?.category ?? null;
}

export function isWaiting(incident: Incident, phase?: DeskStatus | null) {
  return deskStatus(incident, phase) === "waiting";
}

export function caseDeskCategory(incident: Incident): DeskCategory | null {
  const raw = incident.incidentType;
  if (raw && (DESK_CATEGORIES as readonly string[]).includes(raw)) return raw as DeskCategory;
  return sampleCategory(incident);
}

export function categoryText(incident: Incident, t: (key: keyof Messages) => string) {
  const sample = caseDeskCategory(incident);
  if (sample) return t(DESK_CATEGORY_KEY[sample]);
  return categoryLabel(incident.category, t);
}

export function deskCategoryLabel(category: DeskCategory, t: (key: keyof Messages) => string) {
  return t(DESK_CATEGORY_KEY[category]);
}

export function deskStatus(incident: Incident, phase?: DeskStatus | null): DeskStatus {
  if (
    phase === "closed" ||
    phase === "escalated" ||
    phase === "waiting" ||
    phase === "referred" ||
    phase === "claimed" ||
    phase === "en_route" ||
    phase === "on_scene" ||
    phase === "progress" ||
    phase === "resolved" ||
    phase === "new"
  ) {
    return phase;
  }
  if (incident.status === "RESOLVED") return "resolved";
  if (SAMPLE_DESK[incident.trackingId]?.waiting) return "waiting";
  if (incident.status === "UNDER_INVESTIGATION") return "progress";
  if (incident.assignedStation) return "claimed";
  return "new";
}

export function inQueue(incident: Incident, queue: QueueId, phase?: DeskStatus | null, officerId: string = OPERATOR.id) {
  const status = deskStatus(incident, phase);
  if (queue === "unclaimed") return status === "new";
  if (queue === "mine") return incident.assignedStation === officerId && status !== "resolved" && status !== "closed" && status !== "waiting";
  if (queue === "open") return status !== "resolved" && status !== "closed";
  if (queue === "waiting") return status === "waiting";
  return status === "resolved" || status === "closed";
}

export function queueCounts(
  incidents: Incident[],
  phases: Record<string, DeskStatus> = {},
  officerId: string = OPERATOR.id,
): Record<QueueId, number> {
  const phaseOf = (incident: Incident) => phases[incident.trackingId];
  return {
    unclaimed: incidents.filter((item) => inQueue(item, "unclaimed", phaseOf(item), officerId)).length,
    mine: incidents.filter((item) => inQueue(item, "mine", phaseOf(item), officerId)).length,
    open: incidents.filter((item) => inQueue(item, "open", phaseOf(item), officerId)).length,
    waiting: incidents.filter((item) => inQueue(item, "waiting", phaseOf(item), officerId)).length,
    resolved: incidents.filter((item) => inQueue(item, "resolved", phaseOf(item), officerId)).length,
  };
}

export function pinUrgentFirst(incidents: Incident[], phases: Record<string, DeskStatus> = {}) {
  return [...incidents].sort((a, b) => {
    const aPin = a.priority === "P1" && deskStatus(a, phases[a.trackingId]) === "new" ? 0 : 1;
    const bPin = b.priority === "P1" && deskStatus(b, phases[b.trackingId]) === "new" ? 0 : 1;
    if (aPin !== bPin) return aPin - bPin;
    return Date.parse(b.submittedAt) - Date.parse(a.submittedAt);
  });
}

const STATUS_KEY: Record<DeskStatus, keyof Messages> = {
  new: "statusNew",
  claimed: "statusClaimed",
  en_route: "statusEnRoute",
  on_scene: "statusOnScene",
  progress: "statusProgress",
  waiting: "statusWaiting",
  escalated: "statusEscalated",
  referred: "statusReferred",
  resolved: "statusResolved",
  closed: "statusClosed",
};

export function statusLabel(status: DeskStatus, t: (key: keyof Messages) => string) {
  return t(STATUS_KEY[status]);
}

const CATEGORY_KEY: Record<CategoryCode, keyof Messages> = {
  HRSMT: "catHRSMT",
  ASSLT: "catASSLT",
  FRAUD: "catFRAUD",
  TRFCK: "catTRFCK",
  CRRPT: "catCRRPT",
  CRTCL: "catCRTCL",
};

export function categoryLabel(category: CategoryCode, t: (key: keyof Messages) => string) {
  return t(CATEGORY_KEY[category]);
}

const PRIORITY_KEY: Record<Priority, keyof Messages> = {
  P1: "priorityUrgent",
  P2: "priorityHigh",
  P3: "priorityMedium",
  P4: "priorityLow",
};

export function priorityLabel(priority: Priority, t: (key: keyof Messages) => string) {
  return t(PRIORITY_KEY[priority]);
}

export function countryLabel(code: string, t: (key: keyof Messages) => string) {
  if (code === "ET") return t("countryET");
  if (code === "US") return t("countryUS");
  return code;
}

export function hasCoordinates(incident: Incident) {
  if (!incident.location) return false;
  return !(incident.location.latitude === 0 && incident.location.longitude === 0);
}

export function generalArea(incident: Incident, _t?: (key: keyof Messages) => string) {
  return publicPlace(incident);
}

export function exactPlace(incident: Incident) {
  return claimedPlace(incident);
}

export function assigneeName(incident: Incident) {
  if (incident.assigneeName) return incident.assigneeName;
  if (!incident.assignedStation) return null;
  if (incident.assignedStation === OPERATOR.id) return OPERATOR.name;
  return incident.assignedStation;
}

export function summaryOf(incident: Incident) {
  const text = incident.description.replace(/\s+/g, " ").trim();
  return text.length > 96 ? `${text.slice(0, 93)}…` : text;
}

export function relativeTime(iso: string, now: number, t: (key: keyof Messages, vars?: Record<string, string | number>) => string) {
  const delta = Math.max(0, now - Date.parse(iso));
  const minutes = Math.round(delta / 60_000);
  if (minutes < 1) return t("justNow");
  if (minutes < 60) return t("minutesAgo", { n: minutes });
  const hours = Math.round(minutes / 60);
  if (hours < 24) return t("hoursAgo", { n: hours });
  return t("daysAgo", { n: Math.round(hours / 24) });
}

export function formatDuration(ms: number) {
  const minutes = Math.max(1, Math.round(ms / 60_000));
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.round(minutes / 60);
  if (hours < 48) return `${hours}h`;
  return `${Math.round(hours / 24)}d`;
}

export type SlaTone = "ok" | "amber" | "red" | "met";

function responseTarget(priority: Priority) {
  if (priority === "P1") return 15 * 60_000;
  if (priority === "P2") return 60 * 60_000;
  if (priority === "P3") return 4 * 60 * 60_000;
  return 8 * 60 * 60_000;
}

export function firstResponseSla(incident: Incident, now: number): { label: string; tone: SlaTone } {
  const submitted = Date.parse(incident.submittedAt);
  const target = responseTarget(incident.priority);
  const claim = incident.history.find((event) => event.status !== "RECEIVED" || event.note === "Claimed");
  const elapsed = claim ? Date.parse(claim.at) - submitted : Math.max(0, now - submitted);
  const ratio = elapsed / target;
  if (claim) {
    return { label: formatDuration(elapsed), tone: ratio > 1 ? "red" : "met" };
  }
  const tone: SlaTone = ratio >= 1 ? "red" : ratio >= 0.75 ? "amber" : "ok";
  return { label: formatDuration(elapsed), tone };
}

export function resolutionSla(incident: Incident, now: number, phase?: DeskStatus | null): { label: string; tone: SlaTone; paused: boolean } {
  const submitted = Date.parse(incident.submittedAt);
  const target = incident.priority === "P1" ? 4 * 60 * 60_000 : incident.priority === "P2" ? 12 * 60 * 60_000 : 48 * 60 * 60_000;
  const status = deskStatus(incident, phase);
  const paused = status === "waiting";
  if (status === "resolved" || status === "closed") {
    return { label: formatDuration(Date.parse(incident.updatedAt) - submitted), tone: "met", paused: false };
  }
  const elapsed = Math.max(0, now - submitted);
  const ratio = elapsed / target;
  const tone: SlaTone = paused ? "amber" : ratio >= 1 ? "red" : ratio >= 0.75 ? "amber" : "ok";
  return { label: formatDuration(elapsed), tone, paused };
}

export function nextStatus(status: IncidentStatus): IncidentStatus | null {
  if (status === "RECEIVED") return "UNDER_INVESTIGATION";
  if (status === "UNDER_INVESTIGATION") return "RESOLVED";
  return null;
}

export function newTrackingId() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(5));
  let code = "";
  for (const byte of bytes) code += alphabet[byte % alphabet.length];
  return `KST-${code}`;
}

export function spaceTypeLabel(type: SpaceType, t: (key: keyof Messages) => string) {
  const key = {
    police: "spaceTypePolice",
    ngo: "spaceTypeNgo",
    shelter: "spaceTypeShelter",
    health: "spaceTypeHealth",
    legal: "spaceTypeLegal",
  }[type] as keyof Messages;
  return t(key);
}

export function interpolate(template: string, vars?: Record<string, string | number>) {
  return fill(template, vars);
}
