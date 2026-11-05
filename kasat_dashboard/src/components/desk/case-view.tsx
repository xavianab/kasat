"use client";

import { Eye, MoreHorizontal, Share2, Sparkles } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import { useI18n } from "@/components/i18n-provider";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { fetchRevealedIdentity, type RevealedIdentity } from "@/lib/live-desk";
import {
  allowedStatusMoves,
  assigneeName,
  categoryText,
  exactPlace,
  firstResponseSla,
  hasCoordinates,
  priorityLabel,
  publicPlace,
  relativeTime,
  resolutionSla,
  statusLabel,
  type DeskStatus,
} from "@/lib/desk";
import type { IncidentStatus } from "@/lib/types";
import { cn } from "@/lib/utils";

import { PauseMark, PriorityIcon, RelativeTime, StatusLozenge, useNow } from "./bits";
import { CaseAttachments } from "./case-attachments";
import { useDesk } from "./desk-store";
import { Breadcrumbs, PageBody } from "./shell";

export function CaseView({ trackingId }: { trackingId: string }) {
  const { t } = useI18n();
  const desk = useDesk();
  const incident = desk.incidents.find((item) => item.trackingId === trackingId);
  const noteRef = useRef<HTMLTextAreaElement>(null);
  const [tab, setTab] = useState("all");
  const [note, setNote] = useState("");
  const [reply, setReply] = useState("");
  const [showCoords, setShowCoords] = useState(false);
  const [mapOpen, setMapOpen] = useState(false);
  const [linkOpen, setLinkOpen] = useState(false);
  const [linkQuery, setLinkQuery] = useState("");
  const [linkKind, setLinkKind] = useState<"relates" | "duplicate">("relates");
  const [toast, setToast] = useState<string | null>(null);
  const [revealed, setRevealed] = useState<RevealedIdentity | null>(null);
  const [reopenOpen, setReopenOpen] = useState(false);
  const [reopenReason, setReopenReason] = useState("");
  const [reopenError, setReopenError] = useState<string | null>(null);
  const [reopening, setReopening] = useState(false);
  const now = useNow();

  useEffect(() => {
    document.title = `${trackingId} · Kasat Desk`;
  }, [trackingId]);

  useEffect(() => {
    if (!desk.live) return;
    void desk.loadNotes(trackingId).catch(() => {
      // A case outside this station has no notes to show.
    });
  }, [trackingId, desk.live, desk.loadNotes]);

  useEffect(() => {
    if (!desk.live) {
      setRevealed(null);
      return;
    }
    let cancelled = false;
    void fetchRevealedIdentity(trackingId)
      .then((row) => {
        if (!cancelled) setRevealed(row);
      })
      .catch(() => {
        if (!cancelled) setRevealed(null);
      });
    return () => {
      cancelled = true;
    };
  }, [trackingId, desk.live, incident?.assignedStation, incident?.status]);

  useEffect(() => {
    const current = desk.incidents.find((item) => item.trackingId === trackingId);
    if (!current?.assignedStation) return;
    void desk.loadReplies(trackingId).catch(() => {
      // Sample mode has no server messages. A failed read leaves the local list.
    });
  }, [trackingId, desk.incidents, desk.loadReplies]);

  useEffect(() => {
    if (!incident || !incident.assignedStation || !hasCoordinates(incident)) return;
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

  const phase = desk.statusOf(incident);
  const unclaimed = phase === "new";
  const notes = desk.notes.filter((item) => item.trackingId === incident.trackingId);
  const replies = desk.replies.filter((item) => item.trackingId === incident.trackingId);
  const linked = desk.links.filter((item) => item.fromId === incident.trackingId || item.toId === incident.trackingId);
  const matches = desk.incidents.filter((item) => {
    if (item.trackingId === incident.trackingId) return false;
    return item.trackingId.toLowerCase().includes(linkQuery.trim().toLowerCase()) && linkQuery.trim().length > 0;
  });
  const access = desk.log.filter((item) => item.trackingId === incident.trackingId);
  const watching = desk.watches.includes(incident.trackingId);
  const viewer = [...access].reverse().find((item) => item.action === "location_view" || item.action === "claim");
  const claimEvent = [...incident.history].reverse().find((item) => item.status !== "RECEIVED");
  const viewedActor = viewer?.actor ?? claimEvent?.actor;
  const viewedAt = viewer?.at ?? claimEvent?.at;
  const resolution = now ? resolutionSla(incident, now, phase) : null;

  async function copy(value: string, message: string) {
    await navigator.clipboard.writeText(value);
    setToast(message);
    window.setTimeout(() => setToast(null), 1600);
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
          <Button variant="outline" onClick={() => setLinkOpen(true)}>
            {t("linkCase")}
          </Button>
          <DisabledButton label={t("comingSoon")}>{t("refer")}</DisabledButton>
          <Button variant="outline" aria-label={t("watch")} aria-pressed={watching} onClick={() => desk.toggleWatch(incident.trackingId)}>
            <Eye className="h-4 w-4" aria-hidden="true" />
            {watching ? 1 : 0}
          </Button>
          <DropdownMenu>
            <DropdownMenuTrigger className="inline-flex h-8 items-center gap-2 rounded-[6px] border border-primary-fill bg-bg px-3" aria-label={t("share")}>
              <Share2 className="h-4 w-4" aria-hidden="true" />
              {t("share")}
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem
                onSelect={() => copy(`${window.location.origin}/cases/${incident.trackingId}`, t("shareCopied"))}
              >
                {t("copyLink")}
              </DropdownMenuItem>
              <DropdownMenuItem onSelect={() => copy(incident.trackingId, t("keyCopied"))}>
                {t("copyKey")}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          <DropdownMenu>
            <DropdownMenuTrigger className="inline-flex h-8 w-8 items-center justify-center rounded-[6px] border border-primary-fill bg-bg" aria-label={t("more")}>
              <MoreHorizontal className="h-4 w-4" aria-hidden="true" />
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onSelect={() => copy(incident.trackingId, t("keyCopied"))}>
                {t("copyKey")}
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
            <Field label={t("category")}>{categoryText(incident, t)}</Field>
            <Field label={t("reportLanguage")}>
              <Soon />
            </Field>
            <Field label={t("attachments")}>
              {desk.live ? (
                <CaseAttachments trackingId={incident.trackingId} claimed={!unclaimed} />
              ) : incident.attachments.length === 0 ? (
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
            <p>{unclaimed ? publicPlace(incident) : exactPlace(incident)}</p>
            {unclaimed ? <p className="mt-2 text-sm text-muted">{t("exactUnlocks")}</p> : null}
            {!unclaimed && hasCoordinates(incident) && incident.location ? (
              <p className="mt-2 flex flex-wrap gap-3 text-sm">
                <button type="button" className="text-primary hover:underline" onClick={() => setShowCoords((value) => !value)}>
                  {showCoords ? t("hideCoordinates") : t("showCoordinates")}
                </button>
                <button type="button" className="text-primary hover:underline" onClick={() => setMapOpen(true)}>
                  {t("openInMap")}
                </button>
              </p>
            ) : null}
            {!unclaimed && showCoords && incident.location ? (
              <p className="text-sm text-muted">
                {incident.location.latitude.toFixed(5)}, {incident.location.longitude.toFixed(5)}
              </p>
            ) : null}
            {!unclaimed && viewedActor && viewedAt ? (
              <p className="mt-2 text-sm text-muted">
                {t("viewedBy", { officer: viewedActor, time: now ? relativeTime(viewedAt, now, t) : "" })}
              </p>
            ) : null}
          </Card>

          <div className="flex justify-end">
            {/* TODO: When AI summary is built, survivor data must not be sent to any outside AI service without anonymisation and an agreement in place. */}
            <Tooltip>
              <TooltipTrigger asChild>
                <span className="inline-flex" tabIndex={0}>
                  <Button disabled>
                    <Sparkles className="h-4 w-4" aria-hidden="true" />
                    {t("summarizeAi")}
                  </Button>
                </span>
              </TooltipTrigger>
              <TooltipContent>{t("comingSoon")}</TooltipContent>
            </Tooltip>
          </div>
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
                <ReplyList replies={replies} empty={t("noMessages")} />
              </TabsContent>
              <TabsContent value="messages">
                <ReplyList replies={replies} empty={t("noMessages")} />
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
            <div className="mt-4 grid gap-3 border-t border-border pt-3">
              <div className="grid gap-2">
                <p className="text-sm font-medium">{t("addInternalNote")}</p>
                <p className="text-xs text-muted">{t("officersOnly")}</p>
                <label className="sr-only" htmlFor="internal-note">
                  {t("notePlaceholder")}
                </label>
                <textarea
                  id="internal-note"
                  ref={noteRef}
                  value={note}
                  onChange={(event) => setNote(event.target.value)}
                  onKeyDown={(event) => {
                    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
                      event.preventDefault();
                      desk.addNote(incident.trackingId, note);
                      setNote("");
                      setTab("notes");
                    }
                  }}
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
              </div>
              <div className="grid gap-2">
                <p className="text-sm font-medium">{t("replyToSurvivor")}</p>
                {unclaimed ? (
                  <p className="text-sm text-muted">{t("claimToMessage")}</p>
                ) : (
                  <>
                    <label className="sr-only" htmlFor="survivor-reply">
                      {t("replyPlaceholder")}
                    </label>
                    <textarea
                      id="survivor-reply"
                      value={reply}
                      onChange={(event) => setReply(event.target.value)}
                      placeholder={t("replyPlaceholder")}
                      className="min-h-20 rounded-[6px] border border-border bg-bg p-2"
                    />
                    <div className="flex justify-end">
                      <Button
                        variant="primary"
                        onClick={() => {
                          desk.addReply(incident.trackingId, reply);
                          setReply("");
                          setTab("messages");
                        }}
                      >
                        {t("sendReply")}
                      </Button>
                    </div>
                  </>
                )}
              </div>
            </div>
          </Card>
          <Card title={t("linkedCases")}>
            {linked.length === 0 ? (
              <p className="text-sm text-muted">{t("noLinked")}</p>
            ) : (
              <ul className="grid gap-1 text-sm">
                {linked.map((item) => {
                  const other = item.fromId === incident.trackingId ? item.toId : item.fromId;
                  return (
                    <li key={item.id}>
                      <Link href={`/cases/${other}`} className="text-primary hover:underline">
                        {other}
                      </Link>
                      <span className="text-muted"> · {item.kind === "duplicate" ? t("duplicateOf") : t("relatesTo")}</span>
                    </li>
                  );
                })}
              </ul>
            )}
          </Card>
        </div>

        <aside className="order-1 grid w-full gap-3 md:sticky md:top-16 md:order-2 md:w-[280px]">
          <StatusMenu
            label={statusLabel(phase, t)}
            moves={allowedStatusMoves(phase)}
            onMove={(next) => {
              if (next === "claimed") desk.claim(incident.trackingId);
              else if (next === "resolved") desk.resolve(incident.trackingId);
              else desk.setStatus(incident.trackingId, next);
            }}
          />
          {desk.live && phase === "resolved" && (incident.assignedStation === desk.officerId || desk.spaceAdmin) ? (
            <Button
              variant="outline"
              onClick={() => {
                setReopenReason("");
                setReopenError(null);
                setReopenOpen(true);
              }}
            >
              {t("reopenCase")}
            </Button>
          ) : null}
          <Card title={t("slas")}>
            <Field label={t("slaFirst")}>
              {now ? (
                <SlaText sla={firstResponseSla(incident, now)} metLabel={t("slaMet")} />
              ) : (
                <span>{t("awaiting")}</span>
              )}
            </Field>
            <Field label={t("slaResolve")}>
              <span className="inline-flex items-center gap-1">
                {resolution?.paused ? <PauseMark /> : null}
                <span className={cn(resolution?.tone === "red" && "text-danger", resolution?.tone === "amber" && "text-warning", resolution?.tone === "met" && "text-success")}>
                  {resolution ? (incident.status === "RESOLVED" ? t("resolvedIn", { time: resolution.label }) : resolution.label) : "—"}
                </span>
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
            <Field label={t("category")}>{categoryText(incident, t)}</Field>
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
            {revealed?.fullName ? (
              <div className="grid gap-2 text-sm">
                <Field label={t("identityName")}>{revealed.fullName}</Field>
                {revealed.contactHandle ? (
                  <Field label={t("identityPhone")}>{revealed.contactHandle}</Field>
                ) : null}
                {revealed.safeNote ? <Field label={t("identitySafe")}>{revealed.safeNote}</Field> : null}
              </div>
            ) : revealed?.revealed && unclaimed ? (
              <p className="text-sm">{t("identityClaimToView")}</p>
            ) : revealed?.revealed ? (
              <p className="text-sm">{t("identityRestricted")}</p>
            ) : (
              <p className="text-sm">{t("identityHidden")}</p>
            )}
          </Card>
          <p className="text-xs text-muted">
            {t("created")} <RelativeTime iso={incident.submittedAt} />
            {" · "}
            {t("updated")} <RelativeTime iso={incident.updatedAt} />
          </p>
        </aside>
      </div>
      <Dialog open={reopenOpen} onOpenChange={setReopenOpen}>
        <DialogContent closeLabel={t("close")}>
          <DialogTitle>{t("reopenCase")}</DialogTitle>
          <DialogDescription className="mt-1 text-sm text-muted">{t("reopenReason")}</DialogDescription>
          <textarea
            value={reopenReason}
            onChange={(event) => setReopenReason(event.target.value)}
            maxLength={280}
            className="mt-3 min-h-20 w-full rounded-[6px] border border-border bg-bg p-2 text-sm"
          />
          {reopenError ? <p className="mt-2 text-sm text-danger">{reopenError}</p> : null}
          <div className="mt-3 flex justify-end">
            <Button
              variant="primary"
              disabled={reopening || reopenReason.trim().length === 0}
              onClick={() => {
                setReopening(true);
                setReopenError(null);
                void desk
                  .reopen(incident.trackingId, reopenReason.trim())
                  .then(() => {
                    setReopenOpen(false);
                    setReopenReason("");
                  })
                  .catch((cause: unknown) => {
                    setReopenError(cause instanceof Error ? cause.message : "unavailable");
                  })
                  .finally(() => setReopening(false));
              }}
            >
              {t("reopenConfirm")}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
      {toast ? (
        <p role="status" className="fixed right-4 bottom-4 z-50 rounded-[6px] bg-[#172B4D] px-3 py-2 text-sm text-white shadow-lg">
          {toast}
        </p>
      ) : null}
      <Dialog open={mapOpen} onOpenChange={setMapOpen}>
        <DialogContent closeLabel={t("close")}>
          <DialogTitle>{t("mapTitle")}</DialogTitle>
          <DialogDescription className="mt-1 text-sm text-muted">{t("mapStay")}</DialogDescription>
          <p className="mt-3 text-sm">{exactPlace(incident)}</p>
          {incident.location ? (
            <p className="mt-1 text-sm text-muted">
              {incident.location.latitude.toFixed(5)}, {incident.location.longitude.toFixed(5)}
            </p>
          ) : null}
          <svg viewBox="0 0 120 80" className="mt-3 h-32 w-full rounded-[6px] bg-surface" aria-hidden="true">
            <circle cx="62" cy="40" r="6" fill="var(--primary-fill)" />
          </svg>
        </DialogContent>
      </Dialog>
      <Dialog open={linkOpen} onOpenChange={setLinkOpen}>
        <DialogContent closeLabel={t("close")}>
          <DialogTitle>{t("linkDialogTitle")}</DialogTitle>
          <DialogDescription className="mt-1 text-sm text-muted">{t("linkSearch")}</DialogDescription>
          <input
            value={linkQuery}
            onChange={(event) => setLinkQuery(event.target.value)}
            placeholder="KST-"
            className="mt-3 h-8 w-full rounded-[6px] border border-border bg-bg px-2"
          />
          <div className="mt-3 flex gap-3 text-sm">
            <label className="flex items-center gap-2">
              <input type="radio" name="link-kind" checked={linkKind === "relates"} onChange={() => setLinkKind("relates")} />
              {t("relatesTo")}
            </label>
            <label className="flex items-center gap-2">
              <input type="radio" name="link-kind" checked={linkKind === "duplicate"} onChange={() => setLinkKind("duplicate")} />
              {t("duplicateOf")}
            </label>
          </div>
          <ul className="mt-3 grid max-h-40 gap-1 overflow-auto text-sm">
            {matches.length === 0 ? <li className="text-muted">{t("noLinkMatch")}</li> : null}
            {matches.map((item) => (
              <li key={item.trackingId}>
                <button
                  type="button"
                  className="text-primary hover:underline"
                  onClick={() => {
                    desk.linkCases(incident.trackingId, item.trackingId, linkKind);
                    setLinkOpen(false);
                    setLinkQuery("");
                  }}
                >
                  {item.trackingId}
                </button>
              </li>
            ))}
          </ul>
        </DialogContent>
      </Dialog>
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

function StatusMenu({
  label,
  moves,
  onMove,
}: {
  label: string;
  moves: DeskStatus[];
  onMove: (next: DeskStatus) => void;
}) {
  const { t } = useI18n();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="inline-flex h-8 items-center justify-between gap-2 rounded-[6px] bg-primary-fill px-3 text-sm font-medium text-primary-on hover:bg-primary-fill-hover active:bg-primary-fill-pressed">
        {label}
        <span aria-hidden="true">▾</span>
      </DropdownMenuTrigger>
      <DropdownMenuContent>
        <DropdownMenuLabelHidden />
        {moves.length === 0 ? (
          <DropdownMenuItem disabled>{label}</DropdownMenuItem>
        ) : (
          moves.map((move) => (
            <DropdownMenuItem key={move} onSelect={() => onMove(move)}>
              {statusLabel(move, t)}
            </DropdownMenuItem>
          ))
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

function DropdownMenuLabelHidden() {
  const { t } = useI18n();
  return <span className="sr-only">{t("statusAction")}</span>;
}

function historyLabel(
  status: IncidentStatus,
  note: string | null,
  t: (key: "statusNew" | "statusClaimed" | "statusEnRoute" | "statusOnScene" | "statusProgress" | "statusResolved") => string,
) {
  if (note === "Claimed") return t("statusClaimed");
  if (note === "en_route") return t("statusEnRoute");
  if (note === "on_scene") return t("statusOnScene");
  if (status === "RECEIVED") return t("statusNew");
  if (status === "UNDER_INVESTIGATION") return t("statusProgress");
  return t("statusResolved");
}

function SlaText({ sla, metLabel }: { sla: { label: string; tone: string }; metLabel: string }) {
  const tone =
    sla.tone === "red" ? "text-danger" : sla.tone === "amber" ? "text-warning" : sla.tone === "met" ? "text-success" : "text-text";
  return (
    <span className={tone}>
      {sla.label}
      {sla.tone === "met" ? ` · ${metLabel}` : ""}
    </span>
  );
}

function HistoryList({ incidentHistory }: { incidentHistory: { status: IncidentStatus; at: string; actor: string; note: string | null }[] }) {
  const { t } = useI18n();
  if (incidentHistory.length === 0) return <p className="text-sm text-muted">{t("noHistory")}</p>;
  return (
    <ul className="grid gap-2 text-sm">
      {[...incidentHistory].reverse().map((event, index) => (
        <li key={`${event.status}-${event.note ?? "none"}-${event.at}-${index}`}>
          <span className="font-medium">{historyLabel(event.status, event.note, t)}</span>
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

function ReplyList({
  replies,
  empty,
}: {
  replies: { id: string; actor: string; at: string; body: string; sender: string }[];
  empty: string;
}) {
  if (replies.length === 0) return <p className="text-sm text-muted">{empty}</p>;
  return (
    <ul className="mt-2 grid gap-2 text-sm">
      {replies.map((item) => (
        <li key={item.id} className="rounded-[6px] border border-border p-2">
          <p>{item.body}</p>
          <p className="mt-1 text-xs text-muted">
            {item.actor} · <RelativeTime iso={item.at} />
          </p>
        </li>
      ))}
    </ul>
  );
}

function AccessList({ events }: { events: { id: string; action: string; actor: string; at: string; detail?: string }[] }) {
  const { t } = useI18n();
  const label = {
    claim: t("actionClaim"),
    resolve: t("actionResolve"),
    location_view: t("actionLocation"),
    create: t("actionCreate"),
    reply: t("actionReply"),
    note: t("actionNote"),
    status: t("actionStatus"),
    reopen: t("actionReopen"),
    evidence: t("actionEvidence"),
  } as const;
  return (
    <ul className="grid gap-2 text-sm">
      {[...events].reverse().map((event) => (
        <li key={event.id}>
          {label[event.action as keyof typeof label] ?? event.action}
          {event.action === "reopen" && event.detail ? <span className="text-muted"> · {event.detail}</span> : null}
          <span className="text-muted">
            {" · "}
            {event.actor} · <RelativeTime iso={event.at} />
          </span>
        </li>
      ))}
    </ul>
  );
}
