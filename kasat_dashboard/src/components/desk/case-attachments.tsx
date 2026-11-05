"use client";

import { useEffect, useState } from "react";

import { useI18n } from "@/components/i18n-provider";
import {
  fetchAttachmentSummary,
  signedAttachmentUrl,
  viewCaseAttachment,
  type CaseFile,
} from "@/lib/live-desk";

type ShownFile = CaseFile & { url: string | null };

export function CaseAttachments({ trackingId, claimed }: { trackingId: string; claimed: boolean }) {
  const { t } = useI18n();
  const [count, setCount] = useState<number | null>(null);
  const [files, setFiles] = useState<ShownFile[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setCount(null);
    setFiles(null);
    setError(null);
    void (async () => {
      try {
        const summary = await fetchAttachmentSummary(trackingId);
        if (cancelled) return;
        setCount(summary.count);
        if (!claimed || !summary.files) {
          setFiles(null);
          return;
        }
        const shown = await Promise.all(
          summary.files.map(async (file) => {
            await viewCaseAttachment(trackingId, file.objectKey);
            const url = await signedAttachmentUrl(file.objectKey);
            return { ...file, url };
          }),
        );
        if (!cancelled) setFiles(shown);
      } catch (cause) {
        if (!cancelled) setError(cause instanceof Error ? cause.message : "unavailable");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [trackingId, claimed]);

  if (error) return <p className="text-sm text-muted">{error}</p>;
  if (count == null) return <p className="text-sm text-muted">{t("attachments")}</p>;
  if (count === 0) return <span className="text-muted">{t("noAttachments")}</span>;
  if (!claimed || !files) {
    const label = count === 1 ? t("attachmentOne") : t("attachmentMany", { count });
    return <p className="text-sm">{t("claimToView", { label })}</p>;
  }

  return (
    <ul className="grid gap-3">
      {files.map((file) => {
        const name = file.objectKey.split("/").pop() ?? file.objectKey;
        return (
          <li key={file.objectKey} className="grid gap-1 text-sm">
            {file.url ? (
              <img src={file.url} alt="" className="h-24 w-24 rounded-[6px] border border-border object-cover" />
            ) : null}
            <p className="text-muted">{name}</p>
            {file.url ? (
              <a className="w-fit text-primary hover:underline" href={file.url} target="_blank" rel="noopener noreferrer">
                {t("attachmentOpen")}
              </a>
            ) : null}
            <HashLine status={file.integrityStatus} hash={file.evidenceSha256} />
          </li>
        );
      })}
    </ul>
  );
}

function HashLine({ status, hash }: { status: string | null; hash: string | null }) {
  const { t } = useI18n();
  if (!status || status === "none") return null;
  const label =
    status === "verified" ? t("hashVerified") : status === "mismatch" ? t("hashMismatch") : status === "pending_server_hash" ? t("hashPending") : null;
  if (!label) return null;
  const short = hash ? `${hash.slice(0, 12)}…` : null;
  return (
    <p className="text-xs text-muted">
      {label}
      {short ? ` · ${short}` : ""}
    </p>
  );
}
