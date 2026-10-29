import type { DispatchMetrics } from "@/lib/types";

function Metric({
  label,
  value,
  accent,
}: {
  label: string;
  value: string;
  accent?: string;
}) {
  return (
    <div className="metric">
      <div className="label">{label}</div>
      <div className="metric-value" style={accent ? { color: accent } : undefined}>
        {value}
      </div>
    </div>
  );
}

export function MetricsBar({ metrics }: { metrics: DispatchMetrics }) {
  const response =
    metrics.medianResponseMinutes === null
      ? "—"
      : metrics.medianResponseMinutes < 60
        ? `${Math.round(metrics.medianResponseMinutes)}m`
        : `${(metrics.medianResponseMinutes / 60).toFixed(1)}h`;

  return (
    <div className="metrics">
      <Metric label="Total incidents" value={String(metrics.total)} />
      <Metric label="Pending review" value={String(metrics.pending)} accent="var(--info)" />
      <Metric
        label="Under investigation"
        value={String(metrics.investigating)}
        accent="var(--warn)"
      />
      <Metric label="Resolved" value={String(metrics.resolved)} accent="var(--accent)" />
      <Metric label="Median first response" value={response} />
    </div>
  );
}
