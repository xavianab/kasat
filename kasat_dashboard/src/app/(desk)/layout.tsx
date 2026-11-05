import { DeskProvider } from "@/components/desk/desk-store";
import { Shell } from "@/components/desk/shell";
import { fixtureIncidents } from "@/lib/fixtures";

export default function DeskLayout({ children }: { children: React.ReactNode }) {
  return (
    <DeskProvider initialIncidents={fixtureIncidents}>
      <Shell>{children}</Shell>
    </DeskProvider>
  );
}
