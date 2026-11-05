import { getSupabaseBrowserClient, isSupabaseConfigured } from "./supabase";

/**
 * Sends an officer reply when Supabase is connected.
 * Sample mode keeps the reply in memory and does not call this.
 * Internal notes must never be written here.
 */
export async function sendOfficerReply(trackingId: string, body: string) {
  if (!isSupabaseConfigured()) return;
  const supabase = getSupabaseBrowserClient();
  const { error } = await supabase.rpc("send_officer_reply", {
    p_tracking_code: trackingId,
    p_body: body,
  });
  if (error) throw error;
}
