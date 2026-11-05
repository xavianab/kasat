import { notFound } from "next/navigation";
import { Suspense } from "react";

import { QueueView } from "@/components/desk/queue-view";
import { isQueueId } from "@/lib/desk";

export default async function QueuePage({ params }: { params: Promise<{ queue: string }> }) {
  const { queue } = await params;
  if (!isQueueId(queue)) notFound();
  return (
    <Suspense>
      <QueueView queue={queue} />
    </Suspense>
  );
}
