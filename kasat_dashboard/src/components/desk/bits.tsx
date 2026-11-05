"use client";

import {
  Building2,
  ChevronDown,
  ChevronUp,
  ChevronsDown,
  ChevronsUp,
  Equal,
  Heart,
  Home,
  Pause,
  Scale,
  Shield,
} from "lucide-react";
import { useEffect, useState } from "react";

import { useI18n } from "@/components/i18n-provider";
import { useDesk } from "./desk-store";
import {
  assigneeName,
  firstResponseSla,
  generalArea,
  priorityLabel,
  relativeTime,
  statusLabel,
  type DeskStatus,
  type SpaceIcon,
} from "@/lib/desk";
import type { Incident, Priority } from "@/lib/types";
import { cn } from "@/lib/utils";

const LOZENGE: Record<DeskStatus, string> = {
  new: "bg-[#F1F2F4] text-[#44546F] dark:bg-[#2C333A] dark:text-[#C7D1DB]",
  claimed: "bg-[#E9F2FF] text-[#0055CC] dark:bg-[#1C2B41] dark:text-[#85B8FF]",
  progress: "bg-[#E9F2FF] text-[#0055CC] dark:bg-[#1C2B41] dark:text-[#85B8FF]",
  waiting: "bg-[#FFF7D6] text-[#7F5F01] dark:bg-[#3D3418] dark:text-[#F5CD47]",
  escalated: "bg-[#FFF3EB] text-[#A54800] dark:bg-[#3D2B1F] dark:text-[#FEC195]",
  referred: "bg-[#F3F0FF] text-[#5E4DB2] dark:bg-[#2B273F] dark:text-[#B8ACF6]",
  resolved: "bg-[#DCFFF1] text-[#216E4E] dark:bg-[#1C3329] dark:text-[#7EE2B8]",
  closed: "bg-[#F1F2F4] text-[#44546F] dark:bg-[#2C333A] dark:text-[#C7D1DB]",
};

export function StatusLozenge({ incident, status }: { incident?: Incident; status?: DeskStatus }) {
  const { t } = useI18n();
  const desk = useDesk();
  const value = status ?? (incident ? desk.statusOf(incident) : "new");
  return (
    <span className={cn("inline-flex rounded-[3px] px-1.5 py-0.5 text-[11px] font-semibold tracking-wide uppercase", LOZENGE[value])}>
      {statusLabel(value, t)}
    </span>
  );
}

const PRIORITY_ICON = {
  P1: ChevronsUp,
  P2: ChevronUp,
  P3: Equal,
  P4: ChevronDown,
} as const;

const PRIORITY_CLASS: Record<Priority, string> = {
  P1: "text-[#AE2E24]",
  P2: "text-[#C25100]",
  P3: "text-[#7F5F01]",
  P4: "text-[#0C66E4] dark:text-[#579DFF]",
};

export function UrgentLozenge() {
  const { t } = useI18n();
  return (
    <span className="inline-flex rounded-[3px] bg-[#FFECEB] px-1.5 py-0.5 text-[11px] font-semibold tracking-wide text-[#AE2E24] uppercase dark:bg-[#42221F] dark:text-[#F87168]">
      {t("urgentLozenge")}
    </span>
  );
}

export function PriorityIcon({ priority }: { priority: Priority }) {
  const { t } = useI18n();
  const Icon = PRIORITY_ICON[priority];
  return <Icon className={cn("h-4 w-4", PRIORITY_CLASS[priority])} aria-label={priorityLabel(priority, t)} />;
}

export function LowestPriorityIcon() {
  const { t } = useI18n();
  return <ChevronsDown className="h-4 w-4 text-primary" aria-label={t("priorityLowest")} />;
}

export function Assignee({ incident }: { incident: Incident }) {
  const { t } = useI18n();
  const name = assigneeName(incident);
  if (!name) return <span className="text-muted">{t("unassigned")}</span>;
  const initials = name.slice(0, 2).toUpperCase();
  return (
    <span className="inline-flex items-center gap-2">
      <span className="inline-flex h-5 w-5 items-center justify-center rounded-full bg-surface text-[10px] font-semibold text-text" aria-hidden="true">
        {initials}
      </span>
      <span>{name}</span>
    </span>
  );
}

export function RelativeTime({ iso }: { iso: string }) {
  const { t } = useI18n();
  const [now, setNow] = useState<number | null>(null);
  useEffect(() => {
    setNow(Date.now());
  }, [iso]);
  if (now === null) return <span className="text-muted">—</span>;
  return <time dateTime={iso}>{relativeTime(iso, now, t)}</time>;
}

export function SlaBadge({ incident }: { incident: Incident }) {
  const { t } = useI18n();
  const [now, setNow] = useState<number | null>(null);
  useEffect(() => setNow(Date.now()), [incident.updatedAt, incident.submittedAt]);
  if (now === null) return <span className="text-muted">—</span>;
  const sla = firstResponseSla(incident, now);
  const tone =
    sla.tone === "red" ? "text-danger" : sla.tone === "amber" ? "text-warning" : sla.tone === "met" ? "text-success" : "text-text";
  return (
    <span className={tone}>
      {sla.label}
      {sla.tone === "met" ? <span className="sr-only"> {t("slaMet")}</span> : null}
    </span>
  );
}

export function AreaText({ incident }: { incident: Incident }) {
  const { t } = useI18n();
  return <span>{generalArea(incident, t)}</span>;
}

export function SpaceGlyph({ icon, className }: { icon: SpaceIcon; className?: string }) {
  const Icon = { station: Building2, shield: Shield, heart: Heart, scale: Scale, home: Home }[icon];
  return <Icon className={className ?? "h-4 w-4"} aria-hidden="true" />;
}

export function PauseMark() {
  const { t } = useI18n();
  return <Pause className="h-3.5 w-3.5 text-warning" aria-label={t("slaPause")} />;
}

export function useNow() {
  const [now, setNow] = useState<number | null>(null);
  useEffect(() => setNow(Date.now()), []);
  return now;
}
