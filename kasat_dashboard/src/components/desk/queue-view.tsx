"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { useI18n } from "@/components/i18n-provider";
import { Button } from "@/components/ui/button";
import {
  assigneeName,
  categoryText,
  DESK_CATEGORIES,
  deskCategoryLabel,
  deskStatus,
  generalArea,
  inQueue,
  priorityLabel,
  sampleCategory,
  summaryOf,
  type QueueId,
} from "@/lib/desk";
import { isSupabaseConfigured } from "@/lib/supabase";
import type { Priority } from "@/lib/types";
import { cn } from "@/lib/utils";

import { AreaText, Assignee, PriorityIcon, RelativeTime, SlaBadge, StatusLozenge } from "./bits";
import { useDesk } from "./desk-store";
import { Breadcrumbs, PageBody } from "./shell";

const PAGE_SIZE = 50;

export function QueueView({ queue }: { queue: QueueId }) {
  const { t } = useI18n();
  const router = useRouter();
  const params = useSearchParams();
  const { incidents } = useDesk();
  const title =
    queue === "unclaimed"
      ? t("queueUnclaimed")
      : queue === "mine"
        ? t("queueMine")
        : queue === "open"
          ? t("queueOpen")
          : queue === "waiting"
            ? t("queueWaiting")
            : t("queueResolved");

  const [search, setSearch] = useState(params.get("q") ?? "");
  const [status, setStatus] = useState("all");
  const [priority, setPriority] = useState("all");
  const [category, setCategory] = useState("all");
  const [area, setArea] = useState("all");
  const [assignee, setAssignee] = useState("all");
  const [page, setPage] = useState(0);
  const [cursor, setCursor] = useState(0);

  useEffect(() => {
    document.title = `${title} · Kasat Desk`;
  }, [title]);

  const queued = useMemo(() => incidents.filter((item) => inQueue(item, queue)), [incidents, queue]);
  const areas = useMemo(() => Array.from(new Set(queued.map((item) => generalArea(item, t)))).sort(), [queued, t]);
  const assignees = useMemo(
    () => Array.from(new Set(queued.map((item) => assigneeName(item) ?? t("unassigned")))).sort(),
    [queued, t],
  );

  const filtered = queued.filter((item) => {
    const haystack = `${item.trackingId} ${item.description}`.toLowerCase();
    if (search && !haystack.includes(search.toLowerCase())) return false;
    if (status !== "all" && deskStatus(item) !== status) return false;
    if (priority !== "all" && item.priority !== priority) return false;
    if (category !== "all" && sampleCategory(item) !== category) return false;
    if (area !== "all" && generalArea(item, t) !== area) return false;
    if (assignee !== "all" && (assigneeName(item) ?? t("unassigned")) !== assignee) return false;
    return true;
  });

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const safePage = Math.min(page, pageCount - 1);
  const rows = filtered.slice(safePage * PAGE_SIZE, safePage * PAGE_SIZE + PAGE_SIZE);
  const active = Math.min(cursor, Math.max(0, rows.length - 1));

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      const target = event.target as HTMLElement | null;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.tagName === "SELECT")) return;
      if (event.key === "j") setCursor((value) => Math.min(value + 1, rows.length - 1));
      if (event.key === "k") setCursor((value) => Math.max(value - 1, 0));
      if (event.key === "Enter" && rows[active]) router.push(`/cases/${rows[active].trackingId}`);
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [active, rows, router]);

  const filtersActive = search || status !== "all" || priority !== "all" || category !== "all" || area !== "all" || assignee !== "all";

  return (
    <PageBody>
      <Breadcrumbs page={title} />
      <div>
        <h1 className="text-xl font-semibold">{title}</h1>
        {!isSupabaseConfigured() ? <p className="mt-1 text-sm text-muted">{t("fixtureNote")}</p> : null}
      </div>
      <div className="flex flex-wrap items-end gap-2">
        <label className="grid gap-1 text-xs text-muted">
          {t("searchLabel")}
          <input
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
              setPage(0);
            }}
            className="h-8 w-48 rounded-[6px] border border-border bg-bg px-2 text-sm text-text"
          />
        </label>
        <Filter label={t("filterStatus")} value={status} onChange={setStatus}>
          <option value="all">{t("all")}</option>
          <option value="new">{t("statusNew")}</option>
          <option value="claimed">{t("statusClaimed")}</option>
          <option value="progress">{t("statusProgress")}</option>
          <option value="resolved">{t("statusResolved")}</option>
        </Filter>
        <Filter label={t("filterPriority")} value={priority} onChange={setPriority}>
          <option value="all">{t("all")}</option>
          {(["P1", "P2", "P3", "P4"] as Priority[]).map((item) => (
            <option key={item} value={item}>
              {priorityLabel(item, t)}
            </option>
          ))}
        </Filter>
        <Filter label={t("filterCategory")} value={category} onChange={setCategory}>
          <option value="all">{t("all")}</option>
          {DESK_CATEGORIES.map((item) => (
            <option key={item} value={item}>
              {deskCategoryLabel(item, t)}
            </option>
          ))}
        </Filter>
        <Filter label={t("filterArea")} value={area} onChange={setArea}>
          <option value="all">{t("all")}</option>
          {areas.map((item) => (
            <option key={item} value={item}>
              {item}
            </option>
          ))}
        </Filter>
        <Filter label={t("filterAssignee")} value={assignee} onChange={setAssignee}>
          <option value="all">{t("all")}</option>
          {assignees.map((item) => (
            <option key={item} value={item}>
              {item}
            </option>
          ))}
        </Filter>
        {filtersActive ? (
          <Button
            variant="quiet"
            onClick={() => {
              setSearch("");
              setStatus("all");
              setPriority("all");
              setCategory("all");
              setArea("all");
              setAssignee("all");
              setPage(0);
            }}
          >
            {t("clearFilters")}
          </Button>
        ) : null}
      </div>

      <div className="overflow-hidden rounded-[6px] border border-border bg-bg" tabIndex={0} aria-describedby="queue-keys">
        <p id="queue-keys" className="sr-only">
          {t("queueKeys")}
        </p>
        {rows.length === 0 ? (
          <div className="px-4 py-10 text-center">
            <p className="font-medium">{t("emptyTitle")}</p>
            <p className="mt-1 text-sm text-muted">{t("emptyHelp")}</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[880px] border-collapse text-left text-sm">
              <thead>
                <tr className="border-b border-border text-xs text-muted">
                  <th className="px-3 py-2 font-medium">{t("key")}</th>
                  <th className="px-3 py-2 font-medium">{t("summary")}</th>
                  <th className="px-3 py-2 font-medium">{t("category")}</th>
                  <th className="px-3 py-2 font-medium">{t("area")}</th>
                  <th className="px-3 py-2 font-medium">{t("priority")}</th>
                  <th className="px-3 py-2 font-medium">{t("status")}</th>
                  <th className="px-3 py-2 font-medium">{t("assignee")}</th>
                  <th className="px-3 py-2 font-medium">{t("created")}</th>
                  <th className="px-3 py-2 font-medium">{t("sla")}</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((incident, index) => (
                  <tr
                    key={incident.trackingId}
                    aria-selected={index === active}
                    className={cn("cursor-pointer border-b border-border last:border-0 hover:bg-surface", index === active && "bg-surface")}
                    onClick={() => router.push(`/cases/${incident.trackingId}`)}
                  >
                    <td className="px-3 py-2 font-medium">
                      <Link href={`/cases/${incident.trackingId}`} className="hover:underline">
                        {incident.trackingId}
                      </Link>
                    </td>
                    <td className="max-w-[280px] truncate px-3 py-2">{summaryOf(incident)}</td>
                    <td className="px-3 py-2 whitespace-nowrap">{categoryText(incident, t)}</td>
                    <td className="px-3 py-2 whitespace-nowrap">
                      <AreaText incident={incident} />
                    </td>
                    <td className="px-3 py-2">
                      <PriorityIcon priority={incident.priority} />
                    </td>
                    <td className="px-3 py-2">
                      <StatusLozenge incident={incident} />
                    </td>
                    <td className="px-3 py-2">
                      <Assignee incident={incident} />
                    </td>
                    <td className="px-3 py-2 whitespace-nowrap">
                      <RelativeTime iso={incident.submittedAt} />
                    </td>
                    <td className="px-3 py-2 whitespace-nowrap">
                      <SlaBadge incident={incident} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <div className="flex items-center justify-between gap-3 border-t border-border px-3 py-2 text-xs text-muted">
          <span>{t("queueKeys")}</span>
          <span>
            {filtered.length === 0
              ? t("showing", { from: 0, to: 0, total: 0 })
              : t("showing", {
                  from: safePage * PAGE_SIZE + 1,
                  to: safePage * PAGE_SIZE + rows.length,
                  total: filtered.length,
                })}
          </span>
          {pageCount > 1 ? (
            <span className="flex gap-2">
              <Button size="sm" disabled={safePage === 0} onClick={() => setPage(safePage - 1)}>
                {t("backToQueue")}
              </Button>
              <Button size="sm" disabled={safePage >= pageCount - 1} onClick={() => setPage(safePage + 1)}>
                {safePage + 2}
              </Button>
            </span>
          ) : null}
        </div>
      </div>
    </PageBody>
  );
}

function Filter({
  label,
  value,
  onChange,
  children,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  children: React.ReactNode;
}) {
  return (
    <label className="grid gap-1 text-xs text-muted">
      {label}
      <select
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="h-8 rounded-[6px] border border-border bg-bg px-2 text-sm text-text"
      >
        {children}
      </select>
    </label>
  );
}
