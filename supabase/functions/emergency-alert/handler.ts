// Survivor emergency rate-limit + RPC orchestration (testable without Deno.serve).
//
// IP headers (CF-Connecting-IP, X-Forwarded-For) are NOT verified by the
// Supabase Edge platform and can be forged by a caller. Per-IP limits are
// best-effort only. A global flood signal never rejects an alert; per-device
// limits inside trigger_or_coalesce_emergency remain the hard abuse control.

export const CORS_HEADERS = {
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
  p_incident_type?: string | null;
};

/**
 * Best-effort client IP from request headers.
 * These headers are client-influenced / not platform-attested and can be forged.
 */
export function clientIp(req: Request): string {
  const cf = req.headers.get("cf-connecting-ip")?.trim();
  if (cf) return cf;
  const forwarded = req.headers.get("x-forwarded-for") ?? "";
  const parts = forwarded.split(",").map((p) => p.trim()).filter(Boolean);
  // Prefer the rightmost value when a chain is present (often the edge hop),
  // but do not treat any value as unforgeable.
  return parts.at(-1) ?? "";
}

type SoftLimitResult = {
  ipLimited: boolean;
  floodSuspected: boolean;
  ipLimitError?: { status: number; error: string };
};

/** Soft layers only. Never blocks solely for missing IP or global flood. */
export async function applyEmergencySoftLimits(opts: {
  ip: string;
  supabaseUrl: string;
  serviceKey: string;
  fetchFn?: typeof fetch;
  log?: (message: string, data?: Record<string, unknown>) => void;
}): Promise<SoftLimitResult> {
  const fetchFn = opts.fetchFn ?? fetch;
  const log = opts.log ?? ((message, data) => console.log(message, data ?? {}));
  const out: SoftLimitResult = { ipLimited: false, floodSuspected: false };

  // Best-effort per-IP layer when any header-derived IP is present.
  // Headers are forgeable — a fake IP only burns that attacker's own bucket.
  if (opts.ip) {
    const limitRes = await fetchFn(
      `${opts.supabaseUrl}/rest/v1/rpc/check_emergency_ip_limit`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: opts.serviceKey,
          Authorization: `Bearer ${opts.serviceKey}`,
        },
        body: JSON.stringify({ p_ip: opts.ip }),
      },
    );
    if (!limitRes.ok) {
      const text = await limitRes.text();
      const status = text.includes("rate_limit_exceeded") ? 429 : 500;
      out.ipLimited = true;
      out.ipLimitError = {
        status,
        error: status === 429 ? "rate_limit_exceeded" : "rate limit failed",
      };
      return out;
    }
  } else {
    log("emergency-alert: client IP missing; continuing with device limiter + flood signal", {
      reason: "missing_ip",
    });
  }

  // Global soft signal on every request — never rejects the alert.
  const globalRes = await fetchFn(
    `${opts.supabaseUrl}/rest/v1/rpc/check_emergency_global_cap`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: opts.serviceKey,
        Authorization: `Bearer ${opts.serviceKey}`,
      },
      body: "{}",
    },
  );
  if (globalRes.ok) {
    try {
      const status = JSON.parse(await globalRes.text()) as string;
      if (status === "flood_suspected") {
        out.floodSuspected = true;
        log("emergency-alert: flood_suspected; still dispatching emergency", {
          reason: "flood_suspected",
        });
      }
    } catch {
      log("emergency-alert: global cap response unreadable; still dispatching");
    }
  } else {
    log("emergency-alert: global cap RPC failed; still dispatching", {
      status: globalRes.status,
    });
  }

  return out;
}

export async function handleEmergencyRequest(
  req: Request,
  deps?: {
    fetchFn?: typeof fetch;
    env?: Record<string, string | undefined>;
    log?: (message: string, data?: Record<string, unknown>) => void;
  },
): Promise<Response> {
  const fetchFn = deps?.fetchFn ?? fetch;
  const env = deps?.env ?? Deno.env.toObject();
  const log = deps?.log;

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405, headers: CORS_HEADERS });
  }

  const supabaseUrl = env.SUPABASE_URL ?? "";
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY ?? "";
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
  const soft = await applyEmergencySoftLimits({
    ip,
    supabaseUrl,
    serviceKey,
    fetchFn,
    log,
  });

  // Per-IP best-effort only: if that specific IP bucket is full, return 429.
  // Forged IPs cannot empty another caller's real bucket; they only hit their own.
  if (soft.ipLimitError) {
    return Response.json(
      { error: soft.ipLimitError.error },
      { status: soft.ipLimitError.status, headers: CORS_HEADERS },
    );
  }

  // Always dispatch. flood_suspected is logged above and never blocks.
  const rpcRes = await fetchFn(`${supabaseUrl}/rest/v1/rpc/trigger_or_coalesce_emergency`, {
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
      p_incident_type: body.p_incident_type ?? null,
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
}
