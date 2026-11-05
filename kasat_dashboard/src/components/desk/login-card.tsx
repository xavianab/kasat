"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";

import { useI18n } from "@/components/i18n-provider";
import { Button } from "@/components/ui/button";
import { isSupabaseConfigured, getSupabaseBrowserClient } from "@/lib/supabase";

import { KasatMark } from "./kasat-mark";

export function LoginCard() {
  const { t } = useI18n();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const configured = isSupabaseConfigured();

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    if (!configured) {
      setError(t("authNotConfigured"));
      return;
    }
    setPending(true);
    const { error: signInError } = await getSupabaseBrowserClient().auth.signInWithPassword({ email, password });
    setPending(false);
    if (signInError) {
      setError(t("authFailed"));
      return;
    }
    router.push("/queues/unclaimed");
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-surface p-4">
      <div className="w-full max-w-[400px] rounded-[6px] border border-border bg-bg p-6">
        <div className="mb-4 flex items-center gap-2">
          <KasatMark size={22} />
          <h1 className="text-lg font-semibold">{t("signInTitle")}</h1>
        </div>
        <form className="grid gap-3" onSubmit={onSubmit}>
          <label className="grid gap-1 text-sm" htmlFor="email">
            {t("email")}
            <input
              id="email"
              type="email"
              autoComplete="username"
              required
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              className="h-8 rounded-[6px] border border-border bg-bg px-2"
            />
          </label>
          <label className="grid gap-1 text-sm" htmlFor="password">
            {t("password")}
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="h-8 rounded-[6px] border border-border bg-bg px-2"
            />
          </label>
          {error ? (
            <p role="alert" className="text-sm text-danger">
              {error}
            </p>
          ) : null}
          <Button type="submit" variant="primary" disabled={pending}>
            {pending ? t("signingIn") : t("signIn")}
          </Button>
          <p className="text-xs text-muted">{t("authRestricted")}</p>
          {!configured ? (
            <Link href="/queues/unclaimed" className="text-sm text-primary hover:underline">
              {t("openDesk")}
            </Link>
          ) : null}
        </form>
      </div>
    </main>
  );
}
