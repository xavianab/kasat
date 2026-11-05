import type { Incident } from "./types";

/**
 * Local sample queue. These rows are desk-only stand-ins.
 * They are not written to Supabase, and they use no real names or places.
 */
const hoursAgo = (h: number) => new Date(Date.now() - h * 3_600_000).toISOString();

export const fixtureIncidents: Incident[] = [
  {
    trackingId: "KST-8X9P2",
    category: "ASSLT",
    description: "I was assaulted walking home. I don't want my family to know.",
    priority: "P1",
    status: "RECEIVED",
    countryCode: "ET",
    submittedAt: hoursAgo(0.4),
    updatedAt: hoursAgo(0.4),
    history: [{ status: "RECEIVED", at: hoursAgo(0.4), actor: "INTAKE", note: null }],
    location: { latitude: 9.012, longitude: 38.742, precision: "DISTRICT", note: null },
    attachments: [],
    assignedStation: null,
  },
  {
    trackingId: "KST-4RT7Q",
    category: "TRFCK",
    description: "A neighbour is forcing a 15-year-old into marriage next week.",
    priority: "P2",
    status: "RECEIVED",
    countryCode: "ET",
    submittedAt: hoursAgo(0.85),
    updatedAt: hoursAgo(0.85),
    history: [{ status: "RECEIVED", at: hoursAgo(0.85), actor: "INTAKE", note: null }],
    location: { latitude: 8.994, longitude: 38.781, precision: "DISTRICT", note: null },
    attachments: [],
    assignedStation: null,
  },
  {
    trackingId: "KST-3HM6N",
    category: "ASSLT",
    description: "My husband beats me when he comes home drunk.",
    priority: "P2",
    status: "UNDER_INVESTIGATION",
    countryCode: "ET",
    submittedAt: hoursAgo(8),
    updatedAt: hoursAgo(7.8),
    history: [
      { status: "RECEIVED", at: hoursAgo(8), actor: "INTAKE", note: null },
      {
        status: "UNDER_INVESTIGATION",
        at: hoursAgo(7.8),
        actor: "STN-04",
        note: "Claimed. Survivor asked that no one come to the house.",
      },
    ],
    location: { latitude: 9.031, longitude: 38.769, precision: "BLOCK", note: null },
    attachments: [],
    assignedStation: "STN-04",
  },
  {
    trackingId: "KST-7CK2L",
    category: "ASSLT",
    description: "A teacher has been touching students after class.",
    priority: "P1",
    status: "UNDER_INVESTIGATION",
    countryCode: "ET",
    submittedAt: hoursAgo(3),
    updatedAt: hoursAgo(2),
    history: [
      { status: "RECEIVED", at: hoursAgo(3), actor: "INTAKE", note: null },
      {
        status: "UNDER_INVESTIGATION",
        at: hoursAgo(2),
        actor: "STN-04",
        note: "First response was after the target time.",
      },
    ],
    location: { latitude: 8.987, longitude: 38.755, precision: "DISTRICT", note: null },
    attachments: [],
    assignedStation: "STN-04",
  },
  {
    trackingId: "KST-5WP8D",
    category: "HRSMT",
    description:
      "A man follows me from work and waits by the gate. I need a few days before I can speak again.",
    priority: "P3",
    status: "UNDER_INVESTIGATION",
    countryCode: "ET",
    submittedAt: hoursAgo(30),
    updatedAt: hoursAgo(6),
    history: [
      { status: "RECEIVED", at: hoursAgo(30), actor: "INTAKE", note: null },
      {
        status: "UNDER_INVESTIGATION",
        at: hoursAgo(24),
        actor: "STN-04",
        note: "Waiting on the survivor before the next message.",
      },
    ],
    location: null,
    attachments: [],
    assignedStation: "STN-04",
  },
  {
    trackingId: "KST-9WM2K",
    category: "HRSMT",
    description:
      "Someone I trusted shared private photos and said my family would see them. The images were removed and the contact has stopped.",
    priority: "P4",
    status: "RESOLVED",
    countryCode: "ET",
    submittedAt: hoursAgo(200),
    updatedAt: hoursAgo(120),
    history: [
      { status: "RECEIVED", at: hoursAgo(200), actor: "INTAKE", note: null },
      { status: "UNDER_INVESTIGATION", at: hoursAgo(195), actor: "STN-04", note: null },
      {
        status: "RESOLVED",
        at: hoursAgo(120),
        actor: "STN-04",
        note: "Contact stopped. Survivor confirmed she is safe for now.",
      },
    ],
    location: null,
    attachments: [],
    assignedStation: "STN-04",
  },
];
