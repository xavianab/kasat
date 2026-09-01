import type { Incident } from "./types";

/**
 * Stand-in queue so the dashboard renders before Supabase is wired.
 *
 * Shapes are byte-identical to what `kasat_mobile` serialises, so replacing
 * this with a `from("incidents").select()` is a one-line change in the page.
 */
const hoursAgo = (h: number) => new Date(Date.now() - h * 3_600_000).toISOString();

export const fixtureIncidents: Incident[] = [
  {
    trackingId: "KST-8X9P2",
    category: "CRTCL",
    description:
      "Armed group moving through the eastern quarter after curfew. Several residents locked inside a compound.",
    priority: "P1",
    status: "RECEIVED",
    countryCode: "ET",
    submittedAt: hoursAgo(0.4),
    updatedAt: hoursAgo(0.4),
    history: [{ status: "RECEIVED", at: hoursAgo(0.4), actor: "INTAKE", note: null }],
    location: { latitude: -6.79, longitude: 39.21, precision: "DISTRICT", note: null },
    attachments: [],
    assignedStation: null,
  },
  {
    trackingId: "KST-4RT7Q",
    category: "HRSMT",
    description:
      "Repeated unwanted contact from a former colleague over three weeks, escalating to threats made outside my workplace.",
    priority: "P3",
    status: "UNDER_INVESTIGATION",
    countryCode: "ET",
    submittedAt: hoursAgo(31),
    updatedAt: hoursAgo(25),
    history: [
      { status: "RECEIVED", at: hoursAgo(31), actor: "INTAKE", note: null },
      {
        status: "UNDER_INVESTIGATION",
        at: hoursAgo(25),
        actor: "STN-04",
        note: "Assigned to duty officer. Statement corroboration in progress.",
      },
    ],
    location: null,
    attachments: [
      {
        id: "a1c4e9f0",
        label: "EVIDENCE-01",
        mimeType: "image/png",
        byteSize: 412_336,
        storagePath: "incidents/KST-4RT7Q/a1c4e9f0.png",
        strippedMetadata: true,
        width: 1280,
        height: 960,
      },
    ],
    assignedStation: "STN-04",
  },
  {
    trackingId: "KST-9WM2K",
    category: "FRAUD",
    description:
      "Fraudulent transfer requests sent from a spoofed account claiming to be my landlord.",
    priority: "P4",
    status: "RESOLVED",
    countryCode: "ET",
    submittedAt: hoursAgo(216),
    updatedAt: hoursAgo(72),
    history: [
      { status: "RECEIVED", at: hoursAgo(216), actor: "INTAKE", note: null },
      { status: "UNDER_INVESTIGATION", at: hoursAgo(192), actor: "STN-04", note: null },
      {
        status: "RESOLVED",
        at: hoursAgo(72),
        actor: "STN-04",
        note: "Account frozen by the issuing bank. Case closed.",
      },
    ],
    location: null,
    attachments: [],
    assignedStation: "STN-04",
  },
];
