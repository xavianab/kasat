"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";

import {
  DEFAULT_SPACE,
  newTrackingId,
  nextStatus,
  OPERATOR,
  type SpaceDetails,
} from "@/lib/desk";
import type { CategoryCode, Incident, Priority } from "@/lib/types";

const STORAGE_KEY = "kasat.desk.state.v2";
const SPACE_KEY = "kasat.desk.space.v1";

export type AccessAction = "claim" | "resolve" | "location_view" | "create";

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

type CreateInput = {
  description: string;
  category: CategoryCode;
  priority: Priority;
  areaNote: string;
};

type DeskState = {
  incidents: Incident[];
  notes: DeskNote[];
  log: AccessEvent[];
  watches: string[];
};

type DeskValue = DeskState & {
  ready: boolean;
  space: SpaceDetails;
  claim: (trackingId: string) => void;
  resolve: (trackingId: string) => void;
  addNote: (trackingId: string, body: string) => void;
  createCase: (input: CreateInput) => string;
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
    log: [],
    watches: [],
  });
  const [space, setSpace] = useState<SpaceDetails>(DEFAULT_SPACE);
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
            log: parsed.log ?? [],
            watches: parsed.watches ?? [],
          });
        }
      }
      const savedSpace = window.localStorage.getItem(SPACE_KEY);
      if (savedSpace) setSpace(JSON.parse(savedSpace) as SpaceDetails);
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
    setState((current) => ({
      ...current,
      incidents: current.incidents.map((incident) => {
        if (incident.trackingId !== trackingId || incident.status !== "RECEIVED") return incident;
        return {
          ...incident,
          status: "UNDER_INVESTIGATION",
          assignedStation: OPERATOR.id,
          updatedAt: at,
          history: [
            ...incident.history,
            { status: "UNDER_INVESTIGATION", at, actor: OPERATOR.name, note: null },
          ],
        };
      }),
      log: [
        ...current.log,
        { id: eventId(), at, actor: OPERATOR.name, trackingId, action: "claim", detail: "claim" },
        {
          id: eventId(),
          at,
          actor: OPERATOR.name,
          trackingId,
          action: "location_view",
          detail: "location_view",
        },
      ],
    }));
  }, []);

  const resolve = useCallback((trackingId: string) => {
    const at = new Date().toISOString();
    setState((current) => ({
      ...current,
      incidents: current.incidents.map((incident) => {
        if (incident.trackingId !== trackingId || nextStatus(incident.status) !== "RESOLVED") return incident;
        return {
          ...incident,
          status: "RESOLVED",
          updatedAt: at,
          history: [...incident.history, { status: "RESOLVED", at, actor: OPERATOR.name, note: null }],
        };
      }),
      log: [
        ...current.log,
        { id: eventId(), at, actor: OPERATOR.name, trackingId, action: "resolve", detail: "resolve" },
      ],
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

  const value = useMemo<DeskValue>(
    () => ({ ...state, ready, space, claim, resolve, addNote, createCase, logLocationView, toggleWatch, saveSpace }),
    [state, ready, space, claim, resolve, addNote, createCase, logLocationView, toggleWatch, saveSpace],
  );

  return <DeskContext.Provider value={value}>{children}</DeskContext.Provider>;
}

export function useDesk() {
  const value = useContext(DeskContext);
  if (!value) throw new Error("useDesk must be used inside DeskProvider");
  return value;
}
