import { DeskProvider } from "@/components/desk/desk-store";
import { SessionGuard } from "@/components/desk/session-guard";
import { Shell } from "@/components/desk/shell";
import { fixtureIncidents } from "@/lib/fixtures";

const demo = process.env.NEXT_PUBLIC_DEMO_MODE === "true";

export default function DeskLayout({ children }: { children: React.ReactNode }) {
  return (
    <DeskProvider initialIncidents={demo ? fixtureIncidents : []}>
      <SessionGuard />
      <Shell>{children}</Shell>
    </DeskProvider>
  );
}
