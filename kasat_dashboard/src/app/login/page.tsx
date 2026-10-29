/**
 * Station/officer authentication gateway.
 *
 * PART 2: back this with Supabase Auth. Operators sign in against a
 * `stations` table; the `incidents` RLS policies key off that session, which
 * is what keeps the anon key from exposing survivor payloads.
 */
export default function LoginPage() {
  return (
    <div style={{ maxWidth: 380, margin: "64px auto" }}>
      <div className="panel">
        <div className="panel-head">
          <span className="label" style={{ color: "var(--text)" }}>
            Station authentication
          </span>
        </div>
        <div className="panel-body" style={{ display: "grid", gap: 10 }}>
          <span style={{ color: "var(--muted)", fontSize: 12, lineHeight: 1.5 }}>
            Not yet wired. This gateway is a scaffold until Supabase Auth is
            configured for the operator dashboard.
          </span>
          <span className="badge" style={{ color: "var(--warn)" }}>
            PENDING PART 2
          </span>
        </div>
      </div>
    </div>
  );
}
