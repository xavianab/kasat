import { DeskProvider } from "@/components/desk/desk-store";
import { SessionGuard } from "@/components/desk/session-guard";
import { Shell } from "@/components/desk/shell";
import { isDemoModeEnabled } from "@/lib/demo-mode";
import { fixtureIncidents } from "@/lib/fixtures";

const demo = isDemoModeEnabled();

export default function DeskLayout({ children }: { children: React.ReactNode }) {
  return (
    <DeskProvider initialIncidents={demo ? fixtureIncidents : []}>
      <SessionGuard />
      <Shell>{children}</Shell>
    </DeskProvider>
  );
}
