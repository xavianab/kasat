import { redirect } from "next/navigation";

export default async function DispatchCaseRedirect({
  params,
}: {
  params: Promise<{ trackingId: string }>;
}) {
  const { trackingId } = await params;
  redirect(`/cases/${trackingId}`);
}
