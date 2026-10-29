// Triggered when a report moves to status=sent.
// The body is fixed. Never include description, location, photos, or codes.

const GENERIC = "New Kasat report received — log in to view.";

type Webhook = {
  record?: { status?: string; station_id?: string };
  old_record?: { status?: string };
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function webhookAuthorized(req: Request): boolean {
  const secret = Deno.env.get("KASAT_WEBHOOK_SECRET") ?? "";
  if (!secret) return false;
  const header =
    req.headers.get("x-kasat-webhook-secret") ??
    req.headers.get("x-webhook-secret") ??
    "";
  return header === secret;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } });
  }

  if (!webhookAuthorized(req)) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  const payload = (await req.json()) as Webhook;
  const next = payload.record ?? {};
  const prev = payload.old_record ?? {};

  if (next.status !== "sent" || prev.status === "sent") {
    return Response.json({ skipped: true });
  }

  const stationId = next.station_id?.trim() ?? "";
  if (!UUID_RE.test(stationId)) {
    return Response.json({ error: "Invalid station_id" }, { status: 400 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  let email: string | null = null;
  let phone: string | null = null;

  if (supabaseUrl && serviceKey) {
    const res = await fetch(
      `${supabaseUrl}/rest/v1/stations?id=eq.${encodeURIComponent(stationId)}&select=alert_email,alert_phone`,
      { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
    );
    const rows = (await res.json()) as Array<{ alert_email?: string; alert_phone?: string }>;
    email = rows[0]?.alert_email ?? null;
    phone = rows[0]?.alert_phone ?? null;
  }

  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (resendKey && email) {
    await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Kasat <alerts@kasat.app>",
        to: [email],
        subject: "Kasat",
        text: GENERIC,
      }),
    });
  }

  const twilioSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const twilioToken = Deno.env.get("TWILIO_AUTH_TOKEN");
  const twilioFrom = Deno.env.get("TWILIO_FROM_NUMBER");
  if (twilioSid && twilioToken && twilioFrom && phone) {
    const body = new URLSearchParams({
      To: phone,
      From: twilioFrom,
      Body: GENERIC,
    });
    await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${twilioSid}/Messages.json`,
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${btoa(`${twilioSid}:${twilioToken}`)}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body,
      },
    );
  }

  return Response.json({ ok: true, emailed: Boolean(email && resendKey), sms: Boolean(phone && twilioSid) });
});
