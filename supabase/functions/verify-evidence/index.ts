// Server-side evidence hashing Edge Function (`verify-evidence`).
//
// Why this exists:
// A SHA-256 computed on the handset proves nothing for chain of custody because
// a modified client could submit any hash string. This Edge Function runs on
// Supabase's server, downloads the actual bytes stored in `report-photos`,
// computes the authoritative SHA-256 server-side using WebCrypto, compares it
// against the handset's `client_sha256` as a transport-integrity check, and
// records the authoritative hash + UTC verification timestamp via the
// `service_role`-only `record_server_evidence_hash` RPC.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-tracking-code",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type VerifyRequest = {
  tracking_code?: string;
  photo_url?: string;
  object_key?: string;
  client_sha256?: string | null;
  // Support Supabase Storage webhook format (`storage.objects` INSERT/UPDATE)
  record?: {
    bucket_id?: string;
    name?: string;
  };
};

function toHex(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let out = "";
  for (let i = 0; i < bytes.length; i++) {
    out += bytes[i].toString(16).padStart(2, "0");
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceKey) {
      return Response.json(
        { error: "Server configuration missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" },
        { status: 500, headers: CORS_HEADERS },
      );
    }

    const payload = (await req.json()) as VerifyRequest;
    let trackingCode = payload.tracking_code?.trim() ?? "";
    let objectKey = (payload.photo_url ?? payload.object_key)?.trim() ?? "";
    const clientSha256 = payload.client_sha256?.trim() || null;

    // Also support Storage webhook invocations where `record.name` is `<tracking_code>/<file>.png`
    if ((!trackingCode || !objectKey) && payload.record?.name) {
      objectKey = payload.record.name;
      const parts = objectKey.split("/");
      if (parts.length >= 2) {
        trackingCode = parts[0];
      }
    }

    objectKey = objectKey.replace(/^report-photos\//, "");

    if (!trackingCode || !objectKey) {
      return Response.json(
        { error: "tracking_code and photo_url are required" },
        { status: 400, headers: CORS_HEADERS },
      );
    }

    // 1. Download the actual stored bytes from the private `report-photos` bucket
    const encodedKey = objectKey
      .split("/")
      .map((seg) => encodeURIComponent(seg))
      .join("/");
    const storageRes = await fetch(
      `${supabaseUrl}/storage/v1/object/report-photos/${encodedKey}`,
      {
        method: "GET",
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
        },
      },
    );

    if (!storageRes.ok) {
      const detail = await storageRes.text();
      return Response.json(
        { error: `Could not read stored evidence bytes (${storageRes.status})`, detail },
        { status: 404, headers: CORS_HEADERS },
      );
    }

    const fileBytes = await storageRes.arrayBuffer();
    if (fileBytes.byteLength === 0) {
      return Response.json(
        { error: "Stored evidence object is empty (0 bytes)" },
        { status: 422, headers: CORS_HEADERS },
      );
    }

    // 2. Compute authoritative SHA-256 server-side over the actual received bytes
    const digestBuffer = await crypto.subtle.digest("SHA-256", fileBytes);
    const serverSha256 = toHex(digestBuffer);

    // 3. Persist authoritative hash + server UTC verification timestamp via service_role RPC
    const rpcRes = await fetch(
      `${supabaseUrl}/rest/v1/rpc/record_server_evidence_hash`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          p_tracking_code: trackingCode,
          p_photo_url: objectKey,
          p_server_sha256: serverSha256,
          p_client_sha256: clientSha256,
        }),
      },
    );

    if (!rpcRes.ok) {
      const errText = await rpcRes.text();
      return Response.json(
        { error: `Failed to record server hash (${rpcRes.status})`, detail: errText },
        { status: 500, headers: CORS_HEADERS },
      );
    }

    const result = await rpcRes.json();
    const status = result?.transport_match === false ? 422 : 200;
    return Response.json(
      {
        ...result,
        byte_size: fileBytes.byteLength,
      },
      { status, headers: CORS_HEADERS },
    );
  } catch (err) {
    return Response.json(
      { error: err instanceof Error ? err.message : "Unexpected error" },
      { status: 500, headers: CORS_HEADERS },
    );
  }
});
