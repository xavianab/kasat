import { CaseView } from "@/components/desk/case-view";

export default async function CasePage({ params }: { params: Promise<{ trackingId: string }> }) {
  const { trackingId } = await params;
  return <CaseView trackingId={decodeURIComponent(trackingId)} />;
}
