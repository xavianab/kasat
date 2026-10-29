// Authenticated evidence upload. Requires the handset access_secret, stores
// bytes under <tracking_code>/<uuid>.<ext>, and records the server SHA-256.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-kasat-access-secret, x-kasat-object-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const OBJECT_KEY_RE =
  /^KST-[23456789ABCDEFGHJKMNPQRSTVWXYZ]{5}\/[0-9a-fA-F-]{36}\.(png|jpe?g|webp)$/;
const ALLOWED_TYPES = new Set(["image/png", "image/jpeg", "image/webp"]);
const MAX_BYTES = 5 * 1024 * 1024;

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
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405, headers: CORS_HEADERS });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    return Response.json({ error: "Server configuration missing" }, { status: 500, headers: CORS_HEADERS });
  }

  const accessSecret = req.headers.get("x-kasat-access-secret")?.trim() ?? "";
  const objectKey = req.headers.get("x-kasat-object-key")?.trim() ?? "";
  const contentType = (req.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
  if (!accessSecret || !OBJECT_KEY_RE.test(objectKey) || objectKey.includes("..")) {
    return Response.json({ error: "Invalid upload" }, { status: 400, headers: CORS_HEADERS });
  }
  if (!ALLOWED_TYPES.has(contentType)) {
    return Response.json({ error: "Unsupported media type" }, { status: 415, headers: CORS_HEADERS });
  }

  const bytes = await req.arrayBuffer();
  if (bytes.byteLength === 0 || bytes.byteLength > MAX_BYTES) {
    return Response.json({ error: "Invalid payload size" }, { status: 413, headers: CORS_HEADERS });
  }

  const prepareRes = await fetch(`${supabaseUrl}/rest/v1/rpc/prepare_evidence_object`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
    },
    body: JSON.stringify({
      p_access_secret: accessSecret,
      p_object_key: objectKey,
    }),
  });
  if (!prepareRes.ok) {
    return Response.json({ error: "not found" }, { status: 404, headers: CORS_HEADERS });
  }
  const prepared = (await prepareRes.json()) as { tracking_code?: string };
  const trackingCode = prepared.tracking_code ?? objectKey.split("/")[0];
  if (objectKey.split("/")[0] !== trackingCode) {
    return Response.json({ error: "Invalid upload" }, { status: 400, headers: CORS_HEADERS });
  }

  const encodedKey = objectKey
    .split("/")
    .map((seg) => encodeURIComponent(seg))
    .join("/");
  const uploadRes = await fetch(
    `${supabaseUrl}/storage/v1/object/report-photos/${encodedKey}`,
    {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": contentType,
        "x-upsert": "true",
      },
      body: bytes,
    },
  );
  if (!uploadRes.ok) {
    return Response.json({ error: "Upload failed" }, { status: 502, headers: CORS_HEADERS });
  }

  const digestBuffer = await crypto.subtle.digest("SHA-256", bytes);
  const serverSha256 = toHex(digestBuffer);
  const clientSha = req.headers.get("x-kasat-client-sha256")?.trim() || null;

  const hashRes = await fetch(`${supabaseUrl}/rest/v1/rpc/record_server_evidence_hash`, {
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
      p_client_sha256: clientSha,
    }),
  });
  const hashJson = hashRes.ok ? await hashRes.json() : {};

  return Response.json(
    {
      object_key: objectKey,
      tracking_code: trackingCode,
      ...hashJson,
    },
    { status: 200, headers: CORS_HEADERS },
  );
});
