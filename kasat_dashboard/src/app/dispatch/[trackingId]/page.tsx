import Link from "next/link";
import { notFound } from "next/navigation";

import { PriorityBadge, StatusPill } from "@/components/badges";
import { fixtureIncidents } from "@/lib/fixtures";
import { CATEGORY_LABELS, COUNTRY_LABELS, STATUS_LABELS } from "@/lib/types";

export const dynamic = "force-dynamic";

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div style={{ display: "flex", gap: 12, padding: "5px 0" }}>
      <span className="label" style={{ width: 140, flexShrink: 0 }}>
        {label}
      </span>
      <span className="mono" style={{ fontSize: 12 }}>
        {value}
      </span>
    </div>
  );
}

export default async function IncidentPage({
  params,
}: {
  params: Promise<{ trackingId: string }>;
}) {
  const { trackingId } = await params;
  const incident = fixtureIncidents.find((i) => i.trackingId === trackingId);
  if (!incident) notFound();

  return (
    <div style={{ display: "grid", gap: 16 }}>
      <Link href="/dispatch" className="label">
        ← Back to dispatch
      </Link>

      <div className="panel">
        <div className="panel-head">
          <span className="mono" style={{ fontWeight: 800, letterSpacing: "0.12em" }}>
            {incident.trackingId}
          </span>
          <span style={{ flex: 1 }} />
          <PriorityBadge priority={incident.priority} />
          <StatusPill status={incident.status} />
        </div>
        <div className="panel-body">
          <Row label="Category" value={CATEGORY_LABELS[incident.category]} />
          <Row
            label="Country"
            value={COUNTRY_LABELS[incident.countryCode] ?? incident.countryCode}
          />
          <Row label="Submitted" value={incident.submittedAt} />
          <Row label="Station" value={incident.assignedStation ?? "UNASSIGNED"} />
          <Row
            label="Location"
            value={
              incident.location
                ? `${incident.location.latitude.toFixed(3)}, ${incident.location.longitude.toFixed(3)} (±${incident.location.precision})`
                : "Not provided"
            }
          />
          <Row label="Originator" value="NOT RECORDED" />
        </div>
      </div>

      <div className="panel">
        <div className="panel-head">
          <span className="label" style={{ color: "var(--text)" }}>
            Submitted statement
          </span>
        </div>
        <div className="panel-body" style={{ color: "var(--muted)", lineHeight: 1.6 }}>
          {incident.description}
        </div>
      </div>

      <div className="panel">
        <div className="panel-head">
          <span className="label" style={{ color: "var(--text)" }}>
            Attached evidence
          </span>
          <span style={{ flex: 1 }} />
          <span className="badge" style={{ color: "var(--faint)" }}>
            {incident.attachments.length} FILES
          </span>
        </div>
        <div className="panel-body">
          {incident.attachments.length === 0 ? (
            <span className="empty">NO EVIDENCE ATTACHED</span>
          ) : (
            incident.attachments.map((a) => (
              <Row
                key={a.id}
                label={a.label}
                value={`${a.width}×${a.height} · ${(a.byteSize / 1024).toFixed(0)} KB · ${
                  a.strippedMetadata ? "SCRUBBED" : "RAW"
                }`}
              />
            ))
          )}
          {/* PART 2: render signed URLs from the encrypted Supabase Storage bucket. */}
        </div>
      </div>

      <div className="panel">
        <div className="panel-head">
          <span className="label" style={{ color: "var(--text)" }}>
            Audit trail
          </span>
        </div>
        <div className="panel-body">
          {[...incident.history].reverse().map((event) => (
            <Row
              key={`${event.status}-${event.at}`}
              label={STATUS_LABELS[event.status]}
              value={`${event.at} · ${event.actor}${event.note ? ` · ${event.note}` : ""}`}
            />
          ))}
        </div>
      </div>

      {/* PART 2: interactive status updater writing back to Supabase. It must
          append to the audit trail rather than mutate the current status, so a
          case can never silently change hands. */}
    </div>
  );
}
