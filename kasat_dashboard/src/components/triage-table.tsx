import Link from "next/link";

import { CATEGORY_LABELS, COUNTRY_LABELS, type Incident } from "@/lib/types";
import { PriorityBadge, StatusPill, TrackingBadge } from "./badges";

function stamp(iso: string) {
  const d = new Date(iso);
  const two = (n: number) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}-${two(d.getUTCMonth() + 1)}-${two(d.getUTCDate())} ${two(
    d.getUTCHours(),
  )}:${two(d.getUTCMinutes())}Z`;
}

export function TriageTable({ incidents }: { incidents: Incident[] }) {
  if (incidents.length === 0) {
    return <div className="empty">NO INCIDENTS IN QUEUE</div>;
  }

  return (
    <table className="table">
      <thead>
        <tr>
          <th>Tracking ID</th>
          <th>Country</th>
          <th>Type</th>
          <th>Priority</th>
          <th>Submitted</th>
          <th>Station</th>
          <th>Evidence</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        {incidents.map((incident) => (
          <tr key={incident.trackingId}>
            <td>
              <Link href={`/dispatch/${incident.trackingId}`}>
                <TrackingBadge trackingId={incident.trackingId} />
              </Link>
            </td>
            <td className="mono" style={{ fontSize: 11 }}>
              {COUNTRY_LABELS[incident.countryCode] ?? incident.countryCode}
            </td>
            <td>{CATEGORY_LABELS[incident.category]}</td>
            <td>
              <PriorityBadge priority={incident.priority} />
            </td>
            <td className="mono" style={{ color: "var(--muted)", fontSize: 11 }}>
              {stamp(incident.submittedAt)}
            </td>
            <td className="mono" style={{ fontSize: 11 }}>
              {incident.assignedStation ?? "—"}
            </td>
            <td className="mono" style={{ fontSize: 11 }}>
              {incident.attachments.length || "—"}
            </td>
            <td>
              <StatusPill status={incident.status} />
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
