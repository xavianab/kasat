import type { Incident } from "./types";

/**
 * Approximate Addis Ababa sub-city boxes, bundled in the app.
 * Used only when a report has coordinates and no sub-city name.
 * Points are never sent to an outside geocoder.
 */
const SUBCITY_BOXES: { name: string; minLat: number; maxLat: number; minLng: number; maxLng: number }[] = [
  { name: "Addis Ketema", minLat: 9.03, maxLat: 9.055, minLng: 38.7, maxLng: 38.735 },
  { name: "Gulele", minLat: 9.055, maxLat: 9.11, minLng: 38.7, maxLng: 38.78 },
  { name: "Arada", minLat: 9.03, maxLat: 9.055, minLng: 38.735, maxLng: 38.77 },
  { name: "Lideta", minLat: 9.0, maxLat: 9.03, minLng: 38.7, maxLng: 38.74 },
  { name: "Kirkos", minLat: 9.0, maxLat: 9.03, minLng: 38.74, maxLng: 38.77 },
  { name: "Bole", minLat: 8.97, maxLat: 9.03, minLng: 38.77, maxLng: 38.84 },
  { name: "Yeka", minLat: 9.03, maxLat: 9.1, minLng: 38.78, maxLng: 38.86 },
  { name: "Lemi Kura", minLat: 8.98, maxLat: 9.06, minLng: 38.84, maxLng: 38.93 },
  { name: "Nifas Silk-Lafto", minLat: 8.94, maxLat: 9.0, minLng: 38.68, maxLng: 38.76 },
  { name: "Kolfe Keranio", minLat: 8.98, maxLat: 9.05, minLng: 38.64, maxLng: 38.7 },
  { name: "Akaky Kaliti", minLat: 8.84, maxLat: 8.97, minLng: 38.72, maxLng: 38.86 },
];

export function subCityFromCoordinates(latitude: number, longitude: number) {
  const hit = SUBCITY_BOXES.find(
    (box) => latitude >= box.minLat && latitude <= box.maxLat && longitude >= box.minLng && longitude <= box.maxLng,
  );
  return hit?.name ?? null;
}

function cityName(incident: Incident) {
  return incident.countryCode === "ET" ? "Addis Ababa" : incident.countryCode;
}

export function subCityOf(incident: Incident) {
  const named = incident.location?.subCity?.trim();
  if (named) return named;
  if (!incident.location) return null;
  if (incident.location.latitude === 0 && incident.location.longitude === 0) return null;
  return subCityFromCoordinates(incident.location.latitude, incident.location.longitude);
}

/** Tier 1. Sub-city only. Never a coordinate. */
export function publicPlace(incident: Incident) {
  if (!incident.location) return "Location not shared";
  const sub = subCityOf(incident);
  const city = cityName(incident);
  if (sub) return `${sub} sub-city, ${city}`;
  return city;
}

/** Tier 2. Sub-city, woreda, and the survivor's landmark. */
export function claimedPlace(incident: Incident) {
  if (!incident.location) return "Location not shared";
  const sub = subCityOf(incident);
  const head = sub ? `${sub} sub-city` : cityName(incident);
  const woreda = incident.location?.woreda?.trim();
  const landmark = incident.location?.landmark?.trim() || incident.location?.note?.trim() || "";
  const withWoreda = woreda ? `${head}, ${woreda}` : head;
  return landmark ? `${withWoreda} · ${landmark}` : withWoreda;
}
