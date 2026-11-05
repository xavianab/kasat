"use client";

import { Eye, MoreHorizontal, Share2 } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import { useI18n } from "@/components/i18n-provider";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import {
  assigneeName,
  categoryLabel,
  deskStatus,
  generalArea,
  hasCoordinates,
  isUnclaimed,
  priorityLabel,
  relativeTime,
  resolutionSla,
  statusLabel,
} from "@/lib/desk";
import type { IncidentStatus } from "@/lib/types";
import { cn } from "@/lib/utils";

import { PriorityIcon, RelativeTime, StatusLozenge, useNow } from "./bits";
import { useDesk } from "./desk-store";
import { Breadcrumbs, PageBody } from "./shell";

export function CaseView({ trackingId }: { trackingId: string }) {
  const { t } = useI18n();
  const desk = useDesk();
  const incident = desk.incidents.find((item) => item.trackingId === trackingId);
  const noteRef = useRef<HTMLTextAreaElement>(null);
  const [tab, setTab] = useState("all");
  const [note, setNote] = useState("");
  const [copied, setCopied] = useState<"key" | "link" | null>(null);
  const now = useNow();

  useEffect(() => {
    document.title = `${trackingId} · Kasat Desk`;
  }, [trackingId]);

  useEffect(() => {
    if (!incident || isUnclaimed(incident) || !hasCoordinates(incident)) return;
    desk.logLocationView(incident.trackingId);
    // Log once when this claimed case is opened.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [incident?.trackingId, incident?.status]);

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key.toLowerCase() !== "m" || event.metaKey || event.ctrlKey || event.altKey) return;
      const target = event.target as HTMLElement | null;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.tagName === "SELECT")) return;
      event.preventDefault();
      setTab("notes");
      noteRef.current?.focus();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  if (!desk.ready && !incident) {
    return (
      <PageBody>
        <p className="text-sm text-muted">{t("loading")}</p>
      </PageBody>
    );
  }

  if (!incident) {
    return (
      <PageBody>
        <p className="font-medium">{t("caseMissing")}</p>
        <Link href="/queues/unclaimed" className="text-sm text-primary hover:underline">
          {t("backToQueue")}
        </Link>
      </PageBody>
    );
  }

  const unclaimed = isUnclaimed(incident);
  const notes = desk.notes.filter((item) => item.trackingId === incident.trackingId);
  const access = desk.log.filter((item) => item.trackingId === incident.trackingId);
  const watching = desk.watches.includes(incident.trackingId);
  const viewer = [...access].reverse().find((item) => item.action === "location_view" || item.action === "claim");
  const claimEvent = [...incident.history].reverse().find((item) => item.status !== "RECEIVED");
  const viewedActor = viewer?.actor ?? claimEvent?.actor;
  const viewedAt = viewer?.at ?? claimEvent?.at;
  const resolution = now ? resolutionSla(incident, now) : null;
  const first = now
    ? incident.history.find((item) => item.status !== "RECEIVED")
    : null;

  async function copy(value: string, kind: "key" | "link") {
    await navigator.clipboard.writeText(value);
    setCopied(kind);
    window.setTimeout(() => setCopied(null), 1500);
  }

  return (
    <PageBody>
      <Breadcrumbs page={incident.trackingId} />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-xl font-semibold">{incident.trackingId}</h1>
          <p className="mt-1 max-w-3xl text-sm text-muted">{incident.description}</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {unclaimed ? (
            <Button variant="primary" onClick={() => desk.claim(incident.trackingId)}>
              {t("claimCase")}
            </Button>
          ) : null}
          <DisabledButton label={t("comingSoon")}>{t("linkCase")}</DisabledButton>
          <DisabledButton label={t("comingSoon")}>{t("refer")}</DisabledButton>
          <Button variant="outline" aria-label={t("watch")} aria-pressed={watching} onClick={() => desk.toggleWatch(incident.trackingId)}>
            <Eye className="h-4 w-4" aria-hidden="true" />
            {watching ? 1 : 0}
          </Button>
          <Button variant="outline" aria-label={t("share")} onClick={() => copy(window.location.href, "link")}>
            <Share2 className="h-4 w-4" aria-hidden="true" />
            <span className="sr-only">{copied === "link" ? t("shareCopied") : t("share")}</span>
          </Button>
          <DropdownMenu>
            <DropdownMenuTrigger className="inline-flex h-8 w-8 items-center justify-center rounded-[6px] border border-border bg-bg" aria-label={t("more")}>
              <MoreHorizontal className="h-4 w-4" aria-hidden="true" />
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onSelect={() => copy(incident.trackingId, "key")}>
                {copied === "key" ? t("copied") : t("copyKey")}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      <div className="flex flex-col gap-4 md:flex-row md:items-start">
        <div className="order-2 grid min-w-0 flex-1 gap-4 md:order-1">
          <Card title={t("keyDetails")}>
            <p className="text-sm">
              {t("anonymousViaApp")} · <RelativeTime iso={incident.submittedAt} />
            </p>
            <Field label={t("description")}>{incident.description}</Field>
            <Field label={t("category")}>{categoryLabel(incident.category, t)}</Field>
            <Field label={t("reportLanguage")}>
              <Soon />
            </Field>
            <Field label={t("attachments")}>
              {incident.attachments.length === 0 ? (
                <span className="text-muted">{t("noAttachments")}</span>
              ) : (
                <ul className="grid gap-1">
                  {incident.attachments.map((file) => (
                    <li key={file.id}>
                      {file.label} · {t("bytes", { n: Math.round(file.byteSize / 1024) })}
                      {file.strippedMetadata ? ` · ${t("scrubbed")}` : ""}
                    </li>
                  ))}
                </ul>
              )}
            </Field>
          </Card>

          <Card title={t("location")}>
            {unclaimed ? (
              <>
                <p>{generalArea(incident, t)}</p>
                <p className="mt-2 text-sm text-muted">{t("exactUnlocks")}</p>
              </>
            ) : hasCoordinates(incident) && incident.location ? (
              <>
                <p>
                  {t("recordedLocation", {
                    precision: t(`precision${incident.location.precision}` as "precisionDISTRICT"),
                  })}
                </p>
                <p className="mt-1 font-medium">
                  {incident.location.latitude.toFixed(5)}, {incident.location.longitude.toFixed(5)}
                </p>
                {viewedActor && viewedAt ? (
                  <p className="mt-2 text-sm text-muted">
                    {t("viewedBy", { officer: viewedActor, time: now ? relativeTime(viewedAt, now, t) : "" })}
                  </p>
                ) : null}
              </>
            ) : (
              <>
                <p>{generalArea(incident, t)}</p>
                <p className="mt-2 text-sm text-muted">{t("noExactLocation")}</p>
              </>
            )}
          </Card>

          <Card title={t("activity")}>
            <Tabs value={tab} onValueChange={setTab}>
              <TabsList aria-label={t("activity")}>
                <TabsTrigger value="all">{t("tabAll")}</TabsTrigger>
                <TabsTrigger value="messages">{t("tabMessages")}</TabsTrigger>
                <TabsTrigger value="notes">{t("tabNotes")}</TabsTrigger>
                <TabsTrigger value="history">{t("tabHistory")}</TabsTrigger>
                <TabsTrigger value="access">{t("tabAccess")}</TabsTrigger>
              </TabsList>
              <TabsContent value="all">
                <HistoryList incidentHistory={incident.history} />
                <NoteList notes={notes} empty={t("noNotes")} />
              </TabsContent>
              <TabsContent value="messages">
                <p className="text-sm text-muted">{t("noMessages")}</p>
              </TabsContent>
              <TabsContent value="notes">
                <NoteList notes={notes} empty={t("noNotes")} />
              </TabsContent>
              <TabsContent value="history">
                <HistoryList incidentHistory={incident.history} />
              </TabsContent>
              <TabsContent value="access">
                {access.length === 0 ? <p className="text-sm text-muted">{t("noCaseAccess")}</p> : <AccessList events={access} />}
              </TabsContent>
            </Tabs>
            <div className="mt-4 grid gap-2 border-t border-border pt-3">
              <div className="flex gap-2 text-sm">
                <span className="border-b-2 border-primary pb-1">{t("addInternalNote")}</span>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <span tabIndex={0} className="cursor-not-allowed pb-1 text-muted">
                      {t("replyToSurvivor")}
                    </span>
                  </TooltipTrigger>
                  <TooltipContent>{t("replyUnavailable")}</TooltipContent>
                </Tooltip>
              </div>
              <label className="sr-only" htmlFor="internal-note">
                {t("notePlaceholder")}
              </label>
              <textarea
                id="internal-note"
                ref={noteRef}
                value={note}
                onChange={(event) => setNote(event.target.value)}
                placeholder={t("notePlaceholder")}
                className="min-h-20 rounded-[6px] border border-border bg-bg p-2"
              />
              <div className="flex items-center justify-between gap-2">
                <span className="text-xs text-muted">{t("pressM")}</span>
                <Button
                  variant="primary"
                  onClick={() => {
                    desk.addNote(incident.trackingId, note);
                    setNote("");
                    setTab("notes");
                  }}
                >
                  {t("addNote")}
                </Button>
              </div>
              <Tooltip>
                <TooltipTrigger asChild>
                  <span className="inline-flex w-fit" tabIndex={0}>
                    <Button disabled>{t("sendReply")}</Button>
                  </span>
                </TooltipTrigger>
                <TooltipContent>{t("replyUnavailable")}</TooltipContent>
              </Tooltip>
            </div>
          </Card>
        </div>

        <aside className="order-1 grid w-full gap-3 md:sticky md:top-16 md:order-2 md:w-[280px]">
          <StatusMenu
            label={statusLabel(deskStatus(incident), t)}
            canResolve={incident.status === "UNDER_INVESTIGATION"}
            onResolve={() => desk.resolve(incident.trackingId)}
          />
          <Card title={t("slas")}>
            <Field label={t("slaFirst")}>
              {first && now ? (
                <span className="text-success">
                  {relativeTime(first.at, now, t)} · {t("slaMet")}
                </span>
              ) : (
                <span>{t("awaiting")}</span>
              )}
            </Field>
            <Field label={t("slaResolve")}>
              <span className={cn(resolution?.tone === "red" && "text-danger", resolution?.tone === "amber" && "text-warning", resolution?.tone === "met" && "text-success")}>
                {resolution ? (incident.status === "RESOLVED" ? t("resolvedIn", { time: resolution.label }) : resolution.label) : "—"}
              </span>
            </Field>
          </Card>
          <Card title={t("detailsCard")}>
            <Field label={t("assignee")}>
              <span className="grid gap-1">
                <span>{assigneeName(incident) ?? t("unassigned")}</span>
                {unclaimed ? (
                  <button className="w-fit text-primary hover:underline" onClick={() => desk.claim(incident.trackingId)}>
                    {t("assignToMe")}
                  </button>
                ) : null}
              </span>
            </Field>
            <Field label={t("reporter")}>{t("anonymousSurvivor")}</Field>
            <Field label={t("category")}>{categoryLabel(incident.category, t)}</Field>
            <Field label={t("priority")}>
              <span className="inline-flex items-center gap-2">
                <PriorityIcon priority={incident.priority} />
                {priorityLabel(incident.priority, t)}
              </span>
            </Field>
            <Field label={t("space")}>{desk.space.name}</Field>
            <Field label={t("team")}>
              <Soon />
            </Field>
            <Field label={t("labels")}>
              <Soon />
            </Field>
          </Card>
          <Card title={t("identity")}>
            <p className="text-sm">{t("identityHidden")}</p>
          </Card>
          <p className="text-xs text-muted">
            {t("created")} <RelativeTime iso={incident.submittedAt} />
            {" · "}
            {t("updated")} <RelativeTime iso={incident.updatedAt} />
          </p>
        </aside>
      </div>
    </PageBody>
  );
}

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="rounded-[6px] border border-border bg-bg p-3">
      <h2 className="text-sm font-semibold">{title}</h2>
      <div className="mt-2 grid gap-2">{children}</div>
    </section>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="grid gap-0.5 text-sm">
      <span className="text-xs text-muted">{label}</span>
      <div>{children}</div>
    </div>
  );
}

function Soon() {
  const { t } = useI18n();
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span tabIndex={0} className="cursor-not-allowed text-muted underline decoration-dotted">
          {t("comingSoon")}
        </span>
      </TooltipTrigger>
      <TooltipContent>{t("comingSoon")}</TooltipContent>
    </Tooltip>
  );
}

function DisabledButton({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span className="inline-flex" tabIndex={0}>
          <Button disabled>{children}</Button>
        </span>
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  );
}

function StatusMenu({ label, canResolve, onResolve }: { label: string; canResolve: boolean; onResolve: () => void }) {
  const { t } = useI18n();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="inline-flex h-8 items-center justify-between gap-2 rounded-[6px] bg-primary px-3 text-sm font-medium text-white">
        {label}
        <span aria-hidden="true">▾</span>
      </DropdownMenuTrigger>
      <DropdownMenuContent>
        <DropdownMenuLabelHidden />
        {canResolve ? (
          <DropdownMenuItem onSelect={onResolve}>{t("statusResolved")}</DropdownMenuItem>
        ) : (
          <DropdownMenuItem disabled>{label}</DropdownMenuItem>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

function DropdownMenuLabelHidden() {
  const { t } = useI18n();
  return <span className="sr-only">{t("statusAction")}</span>;
}

function historyLabel(status: IncidentStatus, t: (key: "statusNew" | "statusProgress" | "statusResolved") => string) {
  if (status === "RECEIVED") return t("statusNew");
  if (status === "UNDER_INVESTIGATION") return t("statusProgress");
  return t("statusResolved");
}

function HistoryList({ incidentHistory }: { incidentHistory: { status: IncidentStatus; at: string; actor: string; note: string | null }[] }) {
  const { t } = useI18n();
  if (incidentHistory.length === 0) return <p className="text-sm text-muted">{t("noHistory")}</p>;
  return (
    <ul className="grid gap-2 text-sm">
      {[...incidentHistory].reverse().map((event) => (
        <li key={`${event.status}-${event.at}`}>
          <span className="font-medium">{historyLabel(event.status, t)}</span>
          <span className="text-muted">
            {" · "}
            {event.actor}
            {" · "}
            <RelativeTime iso={event.at} />
            {event.note ? ` · ${event.note}` : ""}
          </span>
        </li>
      ))}
    </ul>
  );
}

function NoteList({ notes, empty }: { notes: { id: string; actor: string; at: string; body: string }[]; empty: string }) {
  if (notes.length === 0) return <p className="text-sm text-muted">{empty}</p>;
  return (
    <ul className="mt-2 grid gap-2 text-sm">
      {notes.map((item) => (
        <li key={item.id} className="rounded-[6px] bg-surface p-2">
          <p>{item.body}</p>
          <p className="mt-1 text-xs text-muted">
            {item.actor} · <RelativeTime iso={item.at} />
          </p>
        </li>
      ))}
    </ul>
  );
}

function AccessList({ events }: { events: { id: string; action: string; actor: string; at: string }[] }) {
  const { t } = useI18n();
  const label = {
    claim: t("actionClaim"),
    resolve: t("actionResolve"),
    location_view: t("actionLocation"),
    create: t("actionCreate"),
  } as const;
  return (
    <ul className="grid gap-2 text-sm">
      {[...events].reverse().map((event) => (
        <li key={event.id}>
          {label[event.action as keyof typeof label] ?? event.action}
          <span className="text-muted">
            {" · "}
            {event.actor} · <RelativeTime iso={event.at} />
          </span>
        </li>
      ))}
    </ul>
  );
}
