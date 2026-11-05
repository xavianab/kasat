import { getSupabaseBrowserClient, isSupabaseConfigured } from "./supabase";

export type ListedCaseMessage = {
  id: string;
  sender: "officer" | "survivor";
  body: string;
  created_at: string;
  officer_name: string | null;
};

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

/** Officer read path. Direct selects on case_messages are denied. */
export async function listCaseMessages(trackingId: string): Promise<ListedCaseMessage[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabaseBrowserClient();
  const { data, error } = await supabase.rpc("list_case_messages", {
    p_tracking_code: trackingId,
  });
  if (error) throw error;
  return (data ?? []) as ListedCaseMessage[];
}
