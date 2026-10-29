/**
 * Emergency contacts keyed by ISO 3166-1 alpha-2.
 *
 * Mirror of `kasat_mobile/lib/features/resources/emergency_contacts.dart`.
 * EVERY NUMBER IS A PLACEHOLDER until independently verified. The dashboard
 * does not dial these — they exist so operator tooling can show the same
 * directory the survivor sees, and so a future jurisdiction is a table row
 * rather than a code change.
 */

export type ContactKind = "federalPolice" | "womensAffairs" | "ngo" | "legalAid";

export interface EmergencyContact {
  name: string;
  number: string;
  kind: ContactKind;
  hours: string;
  blurb: string;
  /** Flip only after a real number has been confirmed for the jurisdiction. */
  verified: boolean;
}

export const emergencyContactsByCountry: Record<string, EmergencyContact[]> = {
  ET: [
    {
      name: "Ethiopian Federal Police",
      number: "991",
      kind: "federalPolice",
      hours: "24/7 — Verify 991 placeholder",
      blurb: "Addis Ababa Police Commission / Federal Police emergency dispatch (991).",
      verified: false,
    },
    {
      name: "EWLA Toll-Free GBV Hotline (7711)",
      number: "7711",
      kind: "womensAffairs",
      hours: "Toll-free GBV hotline (Amharic, Afan Oromo, Tigrigna)",
      blurb:
        "Ethiopian Women Lawyers Association (EWLA) confidential GBV support, crisis counselling, and legal guidance — separate from police.",
      verified: false,
    },
    {
      name: "Ministry of Women and Social Affairs hotline",
      number: "+251-000-000-002",
      kind: "womensAffairs",
      hours: "Placeholder",
      blurb: "Government support line for gender-based violence cases.",
      verified: false,
    },
    {
      name: "Regional Women's Affairs Bureau",
      number: "+251-000-000-003",
      kind: "womensAffairs",
      hours: "Placeholder",
      blurb: "Regional caseworkers and referral to shelter services.",
      verified: false,
    },
    {
      name: "Survivor support NGO — counselling",
      number: "+251-000-000-004",
      kind: "ngo",
      hours: "Placeholder",
      blurb: "Confidential counselling and safety planning.",
      verified: false,
    },
    {
      name: "Survivor support NGO — shelter placement",
      number: "+251-000-000-005",
      kind: "ngo",
      hours: "Placeholder",
      blurb: "Emergency accommodation and relocation assistance.",
      verified: false,
    },
    {
      name: "Legal aid clinic",
      number: "+251-000-000-006",
      kind: "legalAid",
      hours: "Placeholder",
      blurb: "Free representation and help filing a formal complaint.",
      verified: false,
    },
  ],
  US: [
    {
      name: "Federal law enforcement line",
      number: "+1-000-000-001",
      kind: "federalPolice",
      hours: "Placeholder",
      blurb: "National reporting line. Number not confirmed.",
      verified: false,
    },
    {
      name: "National domestic violence hotline",
      number: "+1-000-000-002",
      kind: "womensAffairs",
      hours: "Placeholder",
      blurb: "Confidential support for gender-based violence.",
      verified: false,
    },
    {
      name: "Survivor support organisation",
      number: "+1-000-000-003",
      kind: "ngo",
      hours: "Placeholder",
      blurb: "Counselling and safety planning.",
      verified: false,
    },
    {
      name: "Legal aid referral",
      number: "+1-000-000-004",
      kind: "legalAid",
      hours: "Placeholder",
      blurb: "Help finding free or low-cost representation.",
      verified: false,
    },
  ],
};

export function contactsForCountry(countryCode: string | null | undefined): EmergencyContact[] {
  if (!countryCode) return [];
  return emergencyContactsByCountry[countryCode] ?? [];
}
