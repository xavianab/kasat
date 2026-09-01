import {
  PRIORITY_LABELS,
  STATUS_LABELS,
  type IncidentStatus,
  type Priority,
} from "@/lib/types";

const STATUS_COLOR: Record<IncidentStatus, string> = {
  RECEIVED: "var(--info)",
  UNDER_INVESTIGATION: "var(--warn)",
  RESOLVED: "var(--accent)",
};

const PRIORITY_COLOR: Record<Priority, string> = {
  P1: "var(--danger)",
  P2: "var(--warn)",
  P3: "var(--info)",
  P4: "var(--muted)",
};

export function StatusPill({ status }: { status: IncidentStatus }) {
  const color = STATUS_COLOR[status];
  return (
    <span
      className="badge"
      style={{ color, borderColor: color, background: `${color}1f` }}
      title={STATUS_LABELS[status]}
    >
      <span className="dot" />
      {STATUS_LABELS[status]}
    </span>
  );
}

export function PriorityBadge({ priority }: { priority: Priority }) {
  const color = PRIORITY_COLOR[priority];
  return (
    <span
      className="badge"
      style={{ color, borderColor: color }}
      title={PRIORITY_LABELS[priority]}
    >
      {priority}
    </span>
  );
}

export function TrackingBadge({ trackingId }: { trackingId: string }) {
  return (
    <span className="mono" style={{ fontWeight: 700, letterSpacing: "0.1em" }}>
      {trackingId}
    </span>
  );
}
