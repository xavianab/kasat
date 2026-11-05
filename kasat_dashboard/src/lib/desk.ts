import type { Messages } from "./messages";
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

export type DeskStatus = "new" | "claimed" | "progress" | "waiting" | "referred" | "resolved" | "closed";

export type QueueId = "unclaimed" | "mine" | "open" | "waiting" | "resolved";

export const QUEUE_IDS: QueueId[] = ["unclaimed", "mine", "open", "waiting", "resolved"];

export function isQueueId(value: string): value is QueueId {
  return (QUEUE_IDS as string[]).includes(value);
}

/** Tier 1 until an officer has claimed the case. */
export function isUnclaimed(incident: Incident) {
  return incident.status === "RECEIVED" && !incident.assignedStation;
}

export function deskStatus(incident: Incident): DeskStatus {
  if (incident.status === "RESOLVED") return "resolved";
  if (incident.status === "UNDER_INVESTIGATION") return "progress";
  if (incident.assignedStation) return "claimed";
  return "new";
}

export function inQueue(incident: Incident, queue: QueueId) {
  if (queue === "unclaimed") return isUnclaimed(incident);
  if (queue === "mine") return incident.assignedStation === OPERATOR.id && incident.status !== "RESOLVED";
  if (queue === "open") return incident.status !== "RESOLVED";
  if (queue === "waiting") return false;
  return incident.status === "RESOLVED";
}

export function queueCounts(incidents: Incident[]): Record<QueueId, number> {
  return {
    unclaimed: incidents.filter((item) => inQueue(item, "unclaimed")).length,
    mine: incidents.filter((item) => inQueue(item, "mine")).length,
    open: incidents.filter((item) => inQueue(item, "open")).length,
    waiting: incidents.filter((item) => inQueue(item, "waiting")).length,
    resolved: incidents.filter((item) => inQueue(item, "resolved")).length,
  };
}

const STATUS_KEY: Record<DeskStatus, keyof Messages> = {
  new: "statusNew",
  claimed: "statusClaimed",
  progress: "statusProgress",
  waiting: "statusWaiting",
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
  P1: "priorityHighest",
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

export function generalArea(incident: Incident, t: (key: keyof Messages) => string) {
  const country = countryLabel(incident.countryCode, t);
  if (!incident.location) return country;
  const precisionKey = `precision${incident.location.precision}` as keyof Messages;
  const precision = t(precisionKey);
  if (incident.location.note) return incident.location.note;
  return `${precision} · ${country}`;
}

export function assigneeName(incident: Incident) {
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

export function firstResponseSla(incident: Incident, now: number): { label: string; tone: SlaTone } {
  const submitted = Date.parse(incident.submittedAt);
  const target = incident.category === "CRTCL" ? 15 * 60_000 : 3 * 60 * 60_000;
  const claim = incident.history.find((event) => event.status !== "RECEIVED");
  if (claim) {
    return { label: formatDuration(Date.parse(claim.at) - submitted), tone: "met" };
  }
  const elapsed = Math.max(0, now - submitted);
  const ratio = elapsed / target;
  const tone: SlaTone = ratio >= 1 ? "red" : ratio >= 0.75 ? "amber" : "ok";
  return { label: formatDuration(elapsed), tone };
}

export function resolutionSla(incident: Incident, now: number): { label: string; tone: SlaTone; paused: boolean } {
  const submitted = Date.parse(incident.submittedAt);
  const target = 24 * 60 * 60_000;
  if (incident.status === "RESOLVED") {
    return { label: formatDuration(Date.parse(incident.updatedAt) - submitted), tone: "met", paused: false };
  }
  const elapsed = Math.max(0, now - submitted);
  const ratio = elapsed / target;
  const tone: SlaTone = ratio >= 1 ? "red" : ratio >= 0.75 ? "amber" : "ok";
  return { label: formatDuration(elapsed), tone, paused: false };
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
