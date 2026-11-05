import { notFound } from "next/navigation";

import { SettingsView } from "@/components/desk/settings-view";

const SECTIONS = ["details", "people", "permissions", "workflow", "notifications", "language"];

export default async function SettingsPage({ params }: { params: Promise<{ section: string }> }) {
  const { section } = await params;
  if (!SECTIONS.includes(section)) notFound();
  return <SettingsView section={section} />;
}
