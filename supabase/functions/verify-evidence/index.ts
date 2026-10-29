// Storage-webhook-only evidence hashing. Clients cannot invoke this path.
// Object key must be <tracking_code>/<uuid>.<png|jpg|jpeg|webp>. photo_url is
// never rewritten.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-kasat-webhook-secret, x-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const OBJECT_KEY_RE =
  /^KST-[23456789ABCDEFGHJKMNPQRSTVWXYZ]{5}\/[0-9a-fA-F-]{36}\.(png|jpe?g|webp)$/;

type VerifyRequest = {
  tracking_code?: string;
  photo_url?: string;
  object_key?: string;
  client_sha256?: string | null;
  record?: {
    bucket_id?: string;
    name?: string;
  };
};

function webhookAuthorized(req: Request): boolean {
  const secret = Deno.env.get("KASAT_WEBHOOK_SECRET") ?? "";
  if (!secret) return false;
  const header =
    req.headers.get("x-kasat-webhook-secret") ??
    req.headers.get("x-webhook-secret") ??
    "";
  return header === secret;
}

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

  if (!webhookAuthorized(req)) {
    return Response.json({ error: "Unauthorized" }, { status: 401, headers: CORS_HEADERS });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceKey) {
      return Response.json(
        { error: "Server configuration missing" },
        { status: 500, headers: CORS_HEADERS },
      );
    }

    const payload = (await req.json()) as VerifyRequest;
    let objectKey = (payload.record?.name ?? payload.object_key ?? payload.photo_url ?? "")
      .trim()
      .replace(/^report-photos\//, "");
    if (objectKey.includes("..") || objectKey.includes("\\")) {
      return Response.json({ error: "Invalid object key" }, { status: 400, headers: CORS_HEADERS });
    }
    if (payload.record?.bucket_id && payload.record.bucket_id !== "report-photos") {
      return Response.json({ error: "Invalid bucket" }, { status: 400, headers: CORS_HEADERS });
    }
    if (!OBJECT_KEY_RE.test(objectKey)) {
      return Response.json({ error: "Invalid object key" }, { status: 400, headers: CORS_HEADERS });
    }
    const trackingCode = objectKey.split("/")[0];
    const clientSha256 = payload.client_sha256?.trim() || null;

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
      return Response.json(
        { error: "Could not read stored evidence bytes" },
        { status: 404, headers: CORS_HEADERS },
      );
    }

    const fileBytes = await storageRes.arrayBuffer();
    if (fileBytes.byteLength === 0) {
      return Response.json(
        { error: "Stored evidence object is empty" },
        { status: 422, headers: CORS_HEADERS },
      );
    }

    const digestBuffer = await crypto.subtle.digest("SHA-256", fileBytes);
    const serverSha256 = toHex(digestBuffer);

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
      return Response.json(
        { error: "Failed to record server hash" },
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
