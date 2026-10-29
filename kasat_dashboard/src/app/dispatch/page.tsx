import { MetricsBar } from "@/components/metrics-bar";
import { TriageTable } from "@/components/triage-table";
import { fixtureIncidents } from "@/lib/fixtures";
import { isSupabaseConfigured } from "@/lib/supabase";
import { computeMetrics } from "@/lib/types";

export const dynamic = "force-dynamic";

export default function DispatchPage() {
  // PART 2: replace with
  //   supabase.from("incidents").select("*").order("submitted_at", { ascending: false })
  // plus a realtime channel on the same table. The rest of this page does not
  // change — it only ever sees Incident[].
  const incidents = fixtureIncidents;
  const metrics = computeMetrics(incidents);

  return (
    <div style={{ display: "grid", gap: 16 }}>
      <MetricsBar metrics={metrics} />

      {!isSupabaseConfigured() && (
        <div
          className="panel"
          style={{ borderColor: "var(--warn)", background: "rgba(245,158,11,0.06)" }}
        >
          <div className="panel-body" style={{ display: "flex", gap: 10 }}>
            <span className="label" style={{ color: "var(--warn)" }}>
              Fixture mode
            </span>
            <span style={{ color: "var(--muted)", fontSize: 12 }}>
              Supabase is not configured, so this queue is seed data. Copy{" "}
              <code className="mono">.env.example</code> to{" "}
              <code className="mono">.env.local</code> to connect the live table.
            </span>
          </div>
        </div>
      )}

      <div className="panel">
        <div className="panel-head">
          <span className="label" style={{ color: "var(--text)" }}>
            Live dispatch triage
          </span>
          <span style={{ flex: 1 }} />
          <span className="badge" style={{ color: "var(--faint)" }}>
            {incidents.length} IN QUEUE
          </span>
        </div>
        <TriageTable incidents={incidents} />
      </div>
    </div>
  );
}
