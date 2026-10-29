// Survivor emergency entrypoint. Rate-limits by platform-trusted client IP,
// then calls trigger_or_coalesce_emergency with the service role so anon
// cannot skip the limiter by posting the RPC directly.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type EmergencyBody = {
  p_description?: string;
  p_approx_location?: string | null;
  p_silent_mode?: boolean;
  p_latitude?: number | null;
  p_longitude?: number | null;
  p_accuracy_meters?: number | null;
  p_device_secret?: string;
  p_tracking_code?: string | null;
  p_access_secret?: string | null;
};

function clientIp(req: Request): string {
  const cf = req.headers.get("cf-connecting-ip")?.trim();
  if (cf) return cf;
  const forwarded = req.headers.get("x-forwarded-for") ?? "";
  const parts = forwarded.split(",").map((p) => p.trim()).filter(Boolean);
  return parts.at(-1) ?? "";
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

  let body: EmergencyBody;
  try {
    body = (await req.json()) as EmergencyBody;
  } catch {
    return Response.json({ error: "Invalid JSON" }, { status: 400, headers: CORS_HEADERS });
  }

  if (!body.p_device_secret || body.p_device_secret.trim().length < 32) {
    return Response.json({ error: "device secret required" }, { status: 400, headers: CORS_HEADERS });
  }
  if (!body.p_description || body.p_description.trim().length < 40) {
    return Response.json({ error: "description required" }, { status: 400, headers: CORS_HEADERS });
  }

  const ip = clientIp(req);
  if (ip) {
    const limitRes = await fetch(`${supabaseUrl}/rest/v1/rpc/check_emergency_ip_limit`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
      body: JSON.stringify({ p_ip: ip }),
    });
    if (!limitRes.ok) {
      const text = await limitRes.text();
      const status = text.includes("rate_limit_exceeded") ? 429 : 500;
      return Response.json(
        { error: status === 429 ? "rate_limit_exceeded" : "rate limit failed" },
        { status, headers: CORS_HEADERS },
      );
    }
  }

  const rpcRes = await fetch(`${supabaseUrl}/rest/v1/rpc/trigger_or_coalesce_emergency`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
    },
    body: JSON.stringify({
      p_description: body.p_description,
      p_approx_location: body.p_approx_location ?? null,
      p_silent_mode: body.p_silent_mode ?? false,
      p_latitude: body.p_latitude ?? null,
      p_longitude: body.p_longitude ?? null,
      p_accuracy_meters: body.p_accuracy_meters ?? null,
      p_device_secret: body.p_device_secret,
      p_tracking_code: body.p_tracking_code ?? null,
      p_access_secret: body.p_access_secret ?? null,
    }),
  });

  const text = await rpcRes.text();
  if (!rpcRes.ok) {
    const status = text.includes("rate_limit_exceeded") ? 429 : rpcRes.status;
    return Response.json(
      { error: status === 429 ? "rate_limit_exceeded" : "emergency failed" },
      { status, headers: CORS_HEADERS },
    );
  }

  return new Response(text, {
    status: 200,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
});
