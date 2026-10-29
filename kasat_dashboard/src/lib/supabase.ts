import { createClient, type SupabaseClient } from "@supabase/supabase-js";

/**
 * Browser-side Supabase client.
 *
 * Reads go through row level security using the operator's session, so the
 * anon key is safe to ship. `supabase/schema.sql` at the repo root defines the
 * policies this relies on — without them the anon key would expose every
 * survivor payload.
 */
let browserClient: SupabaseClient | null = null;

export function getSupabaseBrowserClient(): SupabaseClient {
  if (browserClient) return browserClient;

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !key) {
    throw new Error(
      "Supabase is not configured. Copy .env.example to .env.local and fill it in.",
    );
  }

  browserClient = createClient(url, key, {
    auth: { persistSession: true, autoRefreshToken: true },
  });
  return browserClient;
}

export const isSupabaseConfigured = () =>
  Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
