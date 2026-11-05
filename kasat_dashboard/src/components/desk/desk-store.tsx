"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";

import { sendOfficerReply } from "@/lib/case-messages";
import {
  allowedStatusMoves,
  DEFAULT_SPACE,
  deskStatus,
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

export type AccessAction = "claim" | "resolve" | "location_view" | "create" | "reply" | "status";

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
  space: SpaceDetails;
  soundAlerts: boolean;
  setSoundAlerts: (on: boolean) => void;
  statusOf: (incident: Incident) => DeskStatus;
  claim: (trackingId: string) => void;
  resolve: (trackingId: string) => void;
  setStatus: (trackingId: string, next: DeskStatus) => void;
  addNote: (trackingId: string, body: string) => void;
  addReply: (trackingId: string, body: string) => void;
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
  const [space, setSpace] = useState<SpaceDetails>(DEFAULT_SPACE);
  const [soundAlerts, setSoundAlertsState] = useState(false);
  const [ready, setReady] = useState(false);
  const incidentsRef = useRef(state.incidents);
  incidentsRef.current = state.incidents;

  useEffect(() => {
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
            alerts: parsed.alerts ?? [],
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
  }, []);

  useEffect(() => {
    if (!ready) return;
    window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }, [ready, state]);

  const claim = useCallback((trackingId: string) => {
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
  }, []);

  const resolve = useCallback((trackingId: string) => {
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
  }, []);

  const setStatus = useCallback((trackingId: string, next: DeskStatus) => {
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
        next === "progress" ? "UNDER_INVESTIGATION" : next === "resolved" || next === "closed" ? "RESOLVED" : incident.status;
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
  }, []);

  const addReply = useCallback((trackingId: string, body: string) => {
    const text = body.trim();
    if (!text) return;
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
    void sendOfficerReply(trackingId, text).catch(() => {
      // Sample mode, or the case is not in Supabase yet. The reply is already on screen.
    });
  }, []);

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
    setState((current) => ({
      ...current,
      notes: [
        ...current.notes,
        { id: eventId(), trackingId, at: new Date().toISOString(), actor: OPERATOR.name, body: text },
      ],
    }));
  }, []);

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
  }, []);

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
    if (!ready || !isSupabaseConfigured()) return;
    const supabase = getSupabaseBrowserClient();
    const channel = supabase
      .channel("desk-urgent")
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "incidents", filter: "priority=eq.P1" }, (payload) => {
        ingestLiveUrgent(payload.new as Record<string, unknown>);
      })
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "incidents", filter: "priority=eq.P1" }, (payload) => {
        ingestLiveUrgent(payload.new as Record<string, unknown>);
      })
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "reports", filter: "is_emergency=eq.true" }, (payload) => {
        ingestLiveUrgent(payload.new as Record<string, unknown>);
      })
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "reports", filter: "is_emergency=eq.true" }, (payload) => {
        ingestLiveUrgent(payload.new as Record<string, unknown>);
      })
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };

    function ingestLiveUrgent(row: Record<string, unknown>) {
      const trackingId = String(row.tracking_id ?? row.tracking_code ?? "");
      if (!trackingId.startsWith("KST-")) return;
      const areaText = typeof row.approx_location === "string" ? row.approx_location : "";
      const area = /^-?\d+\.\d+/.test(areaText) ? "Addis Ababa" : areaText || "Addis Ababa";
      setState((current) => {
        if (current.alerts.some((alert) => alert.trackingId === trackingId && !alert.read)) return current;
        return {
          ...current,
          alerts: [
            {
              id: eventId(),
              trackingId,
              at: new Date().toISOString(),
              category: String(row.incident_type ?? row.category ?? "Other"),
              area,
              read: false,
            },
            ...current.alerts,
          ],
        };
      });
    }
  }, [ready]);

  const value = useMemo<DeskValue>(
    () => ({
      ...state,
      ready,
      space,
      soundAlerts,
      setSoundAlerts,
      statusOf,
      claim,
      resolve,
      setStatus,
      addNote,
      addReply,
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
      space,
      soundAlerts,
      setSoundAlerts,
      statusOf,
      claim,
      resolve,
      setStatus,
      addNote,
      addReply,
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
