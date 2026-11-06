"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";

import { listCaseMessages, sendOfficerReply, type ListedCaseMessage } from "@/lib/case-messages";
import {
  deskToDispatch,
  fetchAccessLog,
  fetchCaseNotes,
  fetchOfficerSession,
  fetchSensitiveReport,
  fetchStationReports,
  mergeReports,
  reportToIncident,
  reopenCase,
  saveCaseNote,
  transitionDispatch,
  type ServerReport,
} from "@/lib/live-desk";
import {
  allowedStatusMoves,
  DEFAULT_SPACE,
  deskStatus,
  dispatchDeskStatus,
  INITIAL_PHASES,
  newTrackingId,
  OPERATOR,
  publicPlace,
  type DeskStatus,
  type SpaceDetails,
} from "@/lib/desk";
import { isSupabaseConfigured, getSupabaseBrowserClient } from "@/lib/supabase";
import type { CategoryCode, Incident, Priority } from "@/lib/types";

const STORAGE_KEY = "kasat.desk.state.v3";
const SPACE_KEY = "kasat.desk.space.v1";
const SOUND_KEY = "kasat.desk.sound";

export type AccessAction = "claim" | "resolve" | "location_view" | "create" | "reply" | "note" | "status" | "reopen" | "evidence";

export type AccessEvent = {
  id: string;
  at: string;
  actor: string;
  trackingId: string;
  action: AccessAction;
  detail: string;
};

export type DeskNote = {
  id: string;
  trackingId: string;
  at: string;
  actor: string;
  body: string;
};

export type DeskReply = {
  id: string;
  trackingId: string;
  at: string;
  actor: string;
  sender: "officer" | "survivor";
  body: string;
};

export type CaseLink = {
  id: string;
  fromId: string;
  toId: string;
  kind: "relates" | "duplicate";
};

export type DeskAlert = {
  id: string;
  trackingId: string;
  at: string;
  category: string;
  area: string;
  read: boolean;
  urgent: boolean;
};

type CreateInput = {
  description: string;
  category: CategoryCode;
  priority: Priority;
  areaNote: string;
};

type DeskState = {
  incidents: Incident[];
  notes: DeskNote[];
  replies: DeskReply[];
  links: CaseLink[];
  alerts: DeskAlert[];
  phases: Record<string, DeskStatus>;
  log: AccessEvent[];
  watches: string[];
};

type DeskValue = DeskState & {
  ready: boolean;
  live: boolean;
  officerId: string;
  loadError: string | null;
  space: SpaceDetails;
  soundAlerts: boolean;
  livePaused: boolean;
  setSoundAlerts: (on: boolean) => void;
  statusOf: (incident: Incident) => DeskStatus;
  claim: (trackingId: string) => void;
  resolve: (trackingId: string) => void;
  reopen: (trackingId: string, reason: string) => Promise<void>;
  spaceAdmin: boolean;
  setStatus: (trackingId: string, next: DeskStatus) => void;
  addNote: (trackingId: string, body: string) => void;
  loadNotes: (trackingId: string) => Promise<void>;
  addReply: (trackingId: string, body: string) => void;
  loadReplies: (trackingId: string) => Promise<void>;
  linkCases: (fromId: string, toId: string, kind: CaseLink["kind"]) => void;
  createCase: (input: CreateInput) => string;
  simulateUrgent: () => string;
  markAlertRead: (id: string) => void;
  markAllAlertsRead: () => void;
  logLocationView: (trackingId: string) => void;
  toggleWatch: (trackingId: string) => void;
  saveSpace: (space: SpaceDetails) => void;
};

const DeskContext = createContext<DeskValue | null>(null);

function eventId() {
  return crypto.randomUUID();
}

function toQueueAlert(incident: Incident): DeskAlert {
  return {
    id: eventId(),
    trackingId: incident.trackingId,
    at: incident.submittedAt,
    category: incident.incidentType || incident.category,
    area: publicPlace(incident),
    read: false,
    urgent: incident.priority === "P1",
  };
}

function applyServerReport(current: DeskState, row: ServerReport): DeskState {
  const incident = reportToIncident(row, true);
  const previous = current.incidents.find((item) => item.trackingId === incident.trackingId);
  if (previous?.location && incident.location && previous.location.latitude !== 0 && incident.location.latitude === 0) {
    incident.location = {
      ...incident.location,
      latitude: previous.location.latitude,
      longitude: previous.location.longitude,
    };
  }
  const exists = current.incidents.some((item) => item.trackingId === incident.trackingId);
  return {
    ...current,
    incidents: exists
      ? current.incidents.map((item) => (item.trackingId === incident.trackingId ? incident : item))
      : [incident, ...current.incidents],
    phases: { ...current.phases, [incident.trackingId]: dispatchDeskStatus(row.dispatch_status) },
  };
}

function repliesFromServer(trackingId: string, rows: ListedCaseMessage[]): DeskReply[] {
  return rows.map((row) => ({
    id: row.id,
    trackingId,
    at: row.created_at,
    actor: row.officer_name ?? (row.sender === "survivor" ? "Survivor" : "Officer"),
    sender: row.sender,
    body: row.body,
  }));
}

export function DeskProvider({
  initialIncidents,
  children,
}: {
  initialIncidents: Incident[];
  children: React.ReactNode;
}) {
  const [state, setState] = useState<DeskState>({
    incidents: initialIncidents,
    notes: [],
    replies: [],
    links: [],
    alerts: [],
    phases: INITIAL_PHASES,
    log: [],
    watches: [],
  });
  const live = isSupabaseConfigured() && process.env.NEXT_PUBLIC_DEMO_MODE !== "true";
  const [space, setSpace] = useState<SpaceDetails>(() =>
    live ? { ...DEFAULT_SPACE, name: "", description: "" } : DEFAULT_SPACE,
  );
  const [soundAlerts, setSoundAlertsState] = useState(false);
  const [livePaused, setLivePaused] = useState(false);
  const [ready, setReady] = useState(false);
  const incidentsRef = useRef(state.incidents);
  incidentsRef.current = state.incidents;
  const [officerId, setOfficerId] = useState(OPERATOR.id);
  const [spaceAdmin, setSpaceAdmin] = useState(false);
  const [stationId, setStationId] = useState<string | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const officerName = useRef(OPERATOR.name);

  useEffect(() => {
    if (live) {
      window.sessionStorage.removeItem(STORAGE_KEY);
      let cancelled = false;
      void (async () => {
        try {
          const session = await fetchOfficerSession();
          if (cancelled) return;
          officerName.current = session.name;
          setOfficerId(session.id);
          setSpaceAdmin(session.spaceAdmin);
          setStationId(session.stationId);
          setSpace((current) => ({
            ...current,
            name: session.stationName || session.stationCode,
            region: session.stationRegion || current.region,
            description: session.generalArea,
            lead: session.name,
            defaultAssignee: session.name,
          }));
          const rows = await fetchStationReports();
          if (cancelled) return;
          const packed = mergeReports(rows, []);
          const log = await fetchAccessLog(packed.incidents);
          if (cancelled) return;
          setState((current) => ({
            ...current,
            incidents: packed.incidents,
            phases: packed.phases,
            notes: [],
            replies: [],
            log,
          }));
          setLoadError(null);
        } catch (error) {
          if (!cancelled) setLoadError(error instanceof Error ? error.message : "unavailable");
        } finally {
          if (!cancelled) setReady(true);
        }
      })();
      return () => {
        cancelled = true;
      };
    }
    try {
      const raw = window.sessionStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as Partial<DeskState>;
        if (Array.isArray(parsed.incidents)) {
          setState({
            incidents: parsed.incidents,
            notes: parsed.notes ?? [],
            replies: parsed.replies ?? [],
            links: parsed.links ?? [],
            alerts: (parsed.alerts ?? []).map((alert) => ({ ...alert, urgent: alert.urgent ?? true })),
            phases: { ...INITIAL_PHASES, ...(parsed.phases ?? {}) },
            log: parsed.log ?? [],
            watches: parsed.watches ?? [],
          });
        }
      }
      const savedSpace = window.localStorage.getItem(SPACE_KEY);
      if (savedSpace) setSpace(JSON.parse(savedSpace) as SpaceDetails);
      setSoundAlertsState(window.localStorage.getItem(SOUND_KEY) === "on");
    } catch {
      // Ignore a damaged local copy and keep the fixture queue.
    }
    setReady(true);
  }, [live]);

  useEffect(() => {
    if (!ready || live) return;
    window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }, [ready, state, live]);

  const refreshLog = useCallback(async (incidents: Incident[]) => {
    const log = await fetchAccessLog(incidents);
    setState((current) => ({ ...current, log }));
  }, []);

  const claim = useCallback((trackingId: string) => {
    if (live) {
      void (async () => {
        try {
          const row = await transitionDispatch(trackingId, "claimed");
          let nextIncidents: Incident[] = [];
          setState((current) => {
            const next = applyServerReport(current, row);
            nextIncidents = next.incidents;
            return {
              ...next,
              alerts: next.alerts.map((alert) =>
                alert.trackingId === trackingId ? { ...alert, read: true } : alert,
              ),
            };
          });
          await refreshLog(nextIncidents);
          setLoadError(null);
        } catch (error) {
          setLoadError(error instanceof Error ? error.message : "unavailable");
        }
      })();
      return;
    }
    const at = new Date().toISOString();
    setState((current) => {
      const incident = current.incidents.find((item) => item.trackingId === trackingId);
      if (!incident || incident.assignedStation || deskStatus(incident, current.phases[trackingId]) !== "new") return current;
      return {
        ...current,
        incidents: current.incidents.map((item) => {
          if (item.trackingId !== trackingId) return item;
          return {
            ...item,
            assignedStation: OPERATOR.id,
            updatedAt: at,
            history: [...item.history, { status: "RECEIVED" as const, at, actor: OPERATOR.name, note: "Claimed" }],
          };
        }),
        phases: { ...current.phases, [trackingId]: "claimed" },
        alerts: current.alerts.map((alert) => (alert.trackingId === trackingId ? { ...alert, read: true } : alert)),
        log: [
          ...current.log,
          { id: eventId(), at, actor: OPERATOR.name, trackingId, action: "claim" as const, detail: "claim" },
          {
            id: eventId(),
            at,
            actor: OPERATOR.name,
            trackingId,
            action: "location_view" as const,
            detail: "location_view",
          },
        ],
      };
    });
  }, [live, refreshLog]);

  const resolve = useCallback((trackingId: string) => {
    if (live) {
      void (async () => {
        try {
          const row = await transitionDispatch(trackingId, "resolved");
          let nextIncidents: Incident[] = [];
          setState((current) => {
            const next = applyServerReport(current, row);
            nextIncidents = next.incidents;
            return next;
          });
          await refreshLog(nextIncidents);
          setLoadError(null);
        } catch (error) {
          setLoadError(error instanceof Error ? error.message : "unavailable");
        }
      })();
      return;
    }
    const at = new Date().toISOString();
    setState((current) => {
      const incident = current.incidents.find((item) => item.trackingId === trackingId);
      if (!incident) return current;
      const phase = deskStatus(incident, current.phases[trackingId]);
      if (!allowedStatusMoves(phase).includes("resolved")) return current;
      return {
        ...current,
        phases: { ...current.phases, [trackingId]: "resolved" },
        incidents: current.incidents.map((item) => {
          if (item.trackingId !== trackingId) return item;
          return {
            ...item,
            status: "RESOLVED",
            updatedAt: at,
            history: [...item.history, { status: "RESOLVED", at, actor: OPERATOR.name, note: null }],
          };
        }),
        log: [
          ...current.log,
          { id: eventId(), at, actor: OPERATOR.name, trackingId, action: "resolve", detail: "resolve" },
        ],
      };
    });
  }, [live, refreshLog]);

  const reopen = useCallback(async (trackingId: string, reason: string) => {
    if (!live) return;
    const row = await reopenCase(trackingId, reason);
    let nextIncidents: Incident[] = [];
    setState((current) => {
      const next = applyServerReport(current, row);
      nextIncidents = next.incidents;
      return next;
    });
    await refreshLog(nextIncidents);
    setLoadError(null);
  }, [live, refreshLog]);

  const setStatus = useCallback((trackingId: string, next: DeskStatus) => {
    const target = deskToDispatch(next);
    if (live && target && target !== "claimed") {
      void (async () => {
        try {
          const row = await transitionDispatch(trackingId, target);
          let nextIncidents: Incident[] = [];
          setState((current) => {
            const updated = applyServerReport(current, row);
            nextIncidents = updated.incidents;
            return updated;
          });
          await refreshLog(nextIncidents);
          setLoadError(null);
        } catch (error) {
          setLoadError(error instanceof Error ? error.message : "unavailable");
        }
      })();
      return;
    }
    setState((current) => {
      const incident = current.incidents.find((item) => item.trackingId === trackingId);
      if (!incident) return current;
      const currentStatus = deskStatus(incident, current.phases[trackingId]);
      if (!allowedStatusMoves(currentStatus).includes(next)) return current;
      if (next === "claimed") {
        return current;
      }
      const at = new Date().toISOString();
      const wire =
        next === "progress" || next === "en_route" || next === "on_scene"
          ? "UNDER_INVESTIGATION"
          : next === "resolved"
            ? "RESOLVED"
            : incident.status;
      return {
        ...current,
        phases: { ...current.phases, [trackingId]: next },
        incidents: current.incidents.map((item) => {
          if (item.trackingId !== trackingId) return item;
          const statusChanged = item.status !== wire;
          return {
            ...item,
            status: wire,
            updatedAt: at,
            history: statusChanged
              ? [...item.history, { status: wire, at, actor: OPERATOR.name, note: null }]
              : item.history,
          };
        }),
        log: [
          ...current.log,
          { id: eventId(), at, actor: OPERATOR.name, trackingId, action: "status", detail: next },
        ],
      };
    });
  }, [live, refreshLog]);

  const addReply = useCallback((trackingId: string, body: string) => {
    const text = body.trim();
    if (!text) return;
    if (live) {
      void (async () => {
        try {
          await sendOfficerReply(trackingId, text);
          const rows = await listCaseMessages(trackingId);
          let nextIncidents: Incident[] = incidentsRef.current;
          setState((current) => {
            nextIncidents = current.incidents;
            return {
              ...current,
              replies: [...current.replies.filter((item) => item.trackingId !== trackingId), ...repliesFromServer(trackingId, rows)],
            };
          });
          await refreshLog(nextIncidents);
          setLoadError(null);
        } catch (error) {
          setLoadError(error instanceof Error ? error.message : "unavailable");
        }
      })();
      return;
    }
    const at = new Date().toISOString();
    setState((current) => {
      const incident = current.incidents.find((item) => item.trackingId === trackingId);
      if (!incident?.assignedStation) return current;
      return {
        ...current,
        replies: [
          ...current.replies,
          { id: eventId(), trackingId, at, actor: OPERATOR.name, sender: "officer", body: text },
        ],
        log: [
          ...current.log,
          { id: eventId(), at, actor: OPERATOR.name, trackingId, action: "reply", detail: "reply" },
        ],
      };
    });
  }, [live, refreshLog]);

  const loadReplies = useCallback(async (trackingId: string) => {
    if (!live) return;
    const rows = await listCaseMessages(trackingId);
    setState((current) => ({
      ...current,
      replies: [...current.replies.filter((item) => item.trackingId !== trackingId), ...repliesFromServer(trackingId, rows)],
    }));
  }, [live]);

  const loadNotes = useCallback(async (trackingId: string) => {
    if (!live) return;
    const rows = await fetchCaseNotes(trackingId);
    setState((current) => ({
      ...current,
      notes: [
        ...current.notes.filter((item) => item.trackingId !== trackingId),
        ...rows.map((row) => ({
          id: row.id,
          trackingId,
          at: row.created_at,
          actor: row.officer_name ?? "Officer",
          body: row.note,
        })),
      ],
    }));
  }, [live]);

  const linkCases = useCallback((fromId: string, toId: string, kind: CaseLink["kind"]) => {
    if (fromId === toId) return;
    setState((current) => {
      if (!current.incidents.some((item) => item.trackingId === toId)) return current;
      const exists = current.links.some(
        (link) => link.fromId === fromId && link.toId === toId && link.kind === kind,
      );
      if (exists) return current;
      return {
        ...current,
        links: [...current.links, { id: eventId(), fromId, toId, kind }],
      };
    });
  }, []);

  const simulateUrgent = useCallback(() => {
    const at = new Date().toISOString();
    const taken = new Set(incidentsRef.current.map((item) => item.trackingId));
    let trackingId = newTrackingId();
    while (taken.has(trackingId)) trackingId = newTrackingId();
    const incident: Incident = {
      trackingId,
      category: "ASSLT",
      description: "Someone is at the door and I need help now. I cannot say more.",
      priority: "P1",
      status: "RECEIVED",
      countryCode: "ET",
      submittedAt: at,
      updatedAt: at,
      history: [{ status: "RECEIVED", at, actor: "INTAKE", note: null }],
      location: {
        latitude: 9.005,
        longitude: 38.81,
        precision: "DISTRICT",
        note: null,
        subCity: "Bole",
        woreda: null,
        landmark: null,
      },
      attachments: [],
      assignedStation: null,
    };
    setState((current) => ({
      ...current,
      incidents: [incident, ...current.incidents],
      phases: { ...current.phases, [trackingId]: "new" },
      alerts: [
        {
          id: eventId(),
          trackingId,
          at,
          category: "Physical assault",
          area: publicPlace(incident),
          read: false,
          urgent: true,
        },
        ...current.alerts,
      ],
    }));
    return trackingId;
  }, []);

  const markAlertRead = useCallback((id: string) => {
    setState((current) => ({
      ...current,
      alerts: current.alerts.map((alert) => (alert.id === id ? { ...alert, read: true } : alert)),
    }));
  }, []);

  const markAllAlertsRead = useCallback(() => {
    setState((current) => ({
      ...current,
      alerts: current.alerts.map((alert) => ({ ...alert, read: true })),
    }));
  }, []);

  const addNote = useCallback((trackingId: string, body: string) => {
    const text = body.trim();
    if (!text) return;
    if (live) {
      void (async () => {
        try {
          await saveCaseNote(trackingId, text);
          const rows = await fetchCaseNotes(trackingId);
          setState((current) => ({
            ...current,
            notes: [
              ...current.notes.filter((item) => item.trackingId !== trackingId),
              ...rows.map((row) => ({
                id: row.id,
                trackingId,
                at: row.created_at,
                actor: row.officer_name ?? officerName.current,
                body: row.note,
              })),
            ],
          }));
          await refreshLog(incidentsRef.current);
          setLoadError(null);
        } catch (error) {
          setLoadError(error instanceof Error ? error.message : "unavailable");
        }
      })();
      return;
    }
    setState((current) => ({
      ...current,
      notes: [
        ...current.notes,
        { id: eventId(), trackingId, at: new Date().toISOString(), actor: OPERATOR.name, body: text },
      ],
    }));
  }, [live, refreshLog]);

  const createCase = useCallback((input: CreateInput) => {
    const at = new Date().toISOString();
    const taken = new Set(incidentsRef.current.map((item) => item.trackingId));
    let trackingId = newTrackingId();
    while (taken.has(trackingId)) trackingId = newTrackingId();
    const incident: Incident = {
      trackingId,
      category: input.category,
      description: input.description.trim(),
      priority: input.priority,
      status: "RECEIVED",
      countryCode: "ET",
      submittedAt: at,
      updatedAt: at,
      history: [{ status: "RECEIVED", at, actor: "INTAKE", note: null }],
      location: input.areaNote.trim()
        ? { latitude: 0, longitude: 0, precision: "DISTRICT", note: input.areaNote.trim() }
        : null,
      attachments: [],
      assignedStation: null,
    };
    setState((current) => ({
      ...current,
      incidents: [incident, ...current.incidents],
      log: [
        ...current.log,
        { id: eventId(), at, actor: OPERATOR.name, trackingId, action: "create", detail: "create" },
      ],
    }));
    return trackingId;
  }, []);

  const logLocationView = useCallback((trackingId: string) => {
    if (live) {
      void (async () => {
        try {
          const current = incidentsRef.current.find((item) => item.trackingId === trackingId);
          const hasCoords = Boolean(
            current?.location && !(current.location.latitude === 0 && current.location.longitude === 0),
          );
          let incidents = incidentsRef.current;
          if (current?.assignedStation && !hasCoords) {
            const row = await fetchSensitiveReport(trackingId);
            setState((existing) => {
              const next = applyServerReport(existing, row);
              incidents = next.incidents;
              return next;
            });
          }
          await refreshLog(incidents);
        } catch (error) {
          setLoadError(error instanceof Error ? error.message : "unavailable");
        }
      })();
      return;
    }
    setState((current) => {
      const already = current.log.some(
        (entry) =>
          entry.trackingId === trackingId && entry.actor === OPERATOR.name && entry.action === "location_view",
      );
      if (already) return current;
      return {
        ...current,
        log: [
          ...current.log,
          {
            id: eventId(),
            at: new Date().toISOString(),
            actor: OPERATOR.name,
            trackingId,
            action: "location_view",
            detail: "location_view",
          },
        ],
      };
    });
  }, [live, refreshLog]);

  const toggleWatch = useCallback((trackingId: string) => {
    setState((current) => ({
      ...current,
      watches: current.watches.includes(trackingId)
        ? current.watches.filter((id) => id !== trackingId)
        : [...current.watches, trackingId],
    }));
  }, []);

  const saveSpace = useCallback((next: SpaceDetails) => {
    setSpace(next);
    window.localStorage.setItem(SPACE_KEY, JSON.stringify(next));
  }, []);

  const setSoundAlerts = useCallback((on: boolean) => {
    setSoundAlertsState(on);
    window.localStorage.setItem(SOUND_KEY, on ? "on" : "off");
  }, []);

  const statusOf = useCallback(
    (incident: Incident) => deskStatus(incident, state.phases[incident.trackingId]),
    [state.phases],
  );

  useEffect(() => {
    if (!ready || !live || !stationId) return;
    const supabase = getSupabaseBrowserClient();
    const known = new Set(incidentsRef.current.map((item) => item.trackingId));
    let stopped = false;
    let timer: number | null = null;

    const pull = async (markReadId: string | null) => {
      try {
        const rows = await fetchStationReports();
        if (stopped) return;
        const packed = mergeReports(rows, incidentsRef.current);
        const incoming = packed.incidents.filter(
          (item) => !known.has(item.trackingId) && packed.phases[item.trackingId] === "new",
        );
        for (const item of packed.incidents) known.add(item.trackingId);
        const urgentIncoming = incoming.filter((item) => item.priority === "P1").map(toQueueAlert);
        const plainIncoming = incoming.filter((item) => item.priority !== "P1").map(toQueueAlert);
        setState((current) => {
          const fresh = [...urgentIncoming, ...plainIncoming].filter(
            (alert) => !current.alerts.some((existing) => existing.trackingId === alert.trackingId),
          );
          return {
            ...current,
            incidents: packed.incidents,
            phases: packed.phases,
            alerts: [...fresh, ...current.alerts].map((alert) =>
              markReadId && alert.trackingId === markReadId ? { ...alert, read: true } : alert,
            ),
          };
        });
        setLoadError(null);
      } catch (error: unknown) {
        if (!stopped) setLoadError(error instanceof Error ? error.message : "unavailable");
      }
    };

    const stopPoll = () => {
      if (timer != null) window.clearInterval(timer);
      timer = null;
    };
    const startPoll = () => {
      if (timer != null) return;
      void pull(null);
      timer = window.setInterval(() => {
        void pull(null);
      }, 30000);
    };

    const channel = supabase
      .channel(`desk-station-${stationId}`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "report_queue_events", filter: `station_id=eq.${stationId}` },
        (payload) => {
          const row = (payload.new ?? {}) as Record<string, unknown>;
          const trackingId = String(row.tracking_code ?? "");
          const dispatchStatus = typeof row.dispatch_status === "string" ? row.dispatch_status : "";
          const markRead =
            trackingId.startsWith("KST-") && dispatchStatus !== "" && dispatchStatus !== "new" ? trackingId : null;
          void pull(markRead);
        },
      )
      .subscribe((status) => {
        if (stopped) return;
        if (status === "SUBSCRIBED") {
          setLivePaused(false);
          stopPoll();
        } else if (status === "CHANNEL_ERROR" || status === "TIMED_OUT" || status === "CLOSED") {
          setLivePaused(true);
          startPoll();
        }
      });
    return () => {
      stopped = true;
      stopPoll();
      void supabase.removeChannel(channel);
    };
  }, [ready, live, stationId]);

  const value = useMemo<DeskValue>(
    () => ({
      ...state,
      ready,
      live,
      officerId,
      loadError,
      space,
      soundAlerts,
      livePaused,
      setSoundAlerts,
      statusOf,
      claim,
      resolve,
      reopen,
      spaceAdmin,
      setStatus,
      addNote,
      loadNotes,
      addReply,
      loadReplies,
      linkCases,
      createCase,
      simulateUrgent,
      markAlertRead,
      markAllAlertsRead,
      logLocationView,
      toggleWatch,
      saveSpace,
    }),
    [
      state,
      ready,
      live,
      officerId,
      loadError,
      space,
      soundAlerts,
      livePaused,
      setSoundAlerts,
      statusOf,
      claim,
      resolve,
      reopen,
      spaceAdmin,
      setStatus,
      addNote,
      loadNotes,
      addReply,
      loadReplies,
      linkCases,
      createCase,
      simulateUrgent,
      markAlertRead,
      markAllAlertsRead,
      logLocationView,
      toggleWatch,
      saveSpace,
    ],
  );

  return <DeskContext.Provider value={value}>{children}</DeskContext.Provider>;
}

export function useDesk() {
  const value = useContext(DeskContext);
  if (!value) throw new Error("useDesk must be used inside DeskProvider");
  return value;
}
