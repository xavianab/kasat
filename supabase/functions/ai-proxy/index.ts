// Server-side Anthropic proxy for community-alert review only.
// The mobile binary never ships an Anthropic API key.
// Callers must present a shared app secret (not the anon JWT alone)
// and a per-installation caller id that is rate-limited server-side.
//
// Honesty note: a shared secret compiled into a mobile app can be extracted
// from the binary. The AI_PROXY_APP_SECRET gate raises the bar above the
// public anon key alone; the per-caller and global rate caps in
// check_ai_proxy_caller_limit are the real cost protection against abuse.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-kasat-proxy-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const REVIEW_SYSTEM = `You are a first-pass safety filter for a community alert board.
You are NOT a fact checker. You cannot confirm whether an event happened.
Decide only whether the text is coherent enough for a human moderator to
read, or whether it should wait in a pending queue.

Send to pending if any of these are true:
- the details contradict each other
- the text is too vague to act on (no who/where/when of any kind)
- it looks like spam, advertising, or a copy-paste scam
- it contains harassment, slurs, or threats toward a named person
- it asks people to pay money or click a link

Otherwise verdict is publish.

Reply with JSON only: {"verdict":"publish"|"pending","note":"short reason"}`;

const MAX_TITLE_CHARS = 80;
const MAX_BODY_CHARS = 600;

function stripIdentifying(text: string, maxChars: number): string {
  return text
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, "[redacted-email]")
    .replace(/\b(?:\+?251|0)?[79]\d{8}\b/g, "[redacted-phone]")
    .replace(/\b\+?\d[\d\s().-]{7,}\d\b/g, "[redacted-number]")
    .slice(0, maxChars);
}

type ProxyBody = {
  kind?: string;
  body?: string;
  title?: string;
  caller_id?: string;
};

/** Compare secrets via equal-length digests so length mismatches do not short-circuit. */
async function secretsEqual(presented: string, expected: string): Promise<boolean> {
  const enc = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", enc.encode(presented)),
    crypto.subtle.digest("SHA-256", enc.encode(expected)),
  ]);
  const av = new Uint8Array(a);
  const bv = new Uint8Array(b);
  let mismatch = 0;
  for (let i = 0; i < av.length; i++) {
    mismatch |= av[i] ^ bv[i];
  }
  return mismatch === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405, headers: CORS_HEADERS });
  }

  // Fail closed: unset or short secrets reject every request (including otherwise valid ones).
  const expectedSecret = Deno.env.get("AI_PROXY_APP_SECRET") ?? "";
  if (!expectedSecret || expectedSecret.length < 32) {
    return Response.json({ error: "Review service is not configured" }, { status: 503, headers: CORS_HEADERS });
  }
  const presentedSecret = req.headers.get("x-kasat-proxy-secret") ?? "";
  if (!(await secretsEqual(presentedSecret, expectedSecret))) {
    return Response.json({ error: "unauthorized" }, { status: 401, headers: CORS_HEADERS });
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
  if (!apiKey) {
    return Response.json({ error: "Review service is not configured" }, { status: 503, headers: CORS_HEADERS });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    return Response.json({ error: "Server configuration missing" }, { status: 500, headers: CORS_HEADERS });
  }

  let payload: ProxyBody;
  try {
    payload = (await req.json()) as ProxyBody;
  } catch {
    return Response.json({ error: "Invalid JSON" }, { status: 400, headers: CORS_HEADERS });
  }

  if (payload.kind !== "review") {
    return Response.json({ error: "unsupported kind" }, { status: 400, headers: CORS_HEADERS });
  }

  const callerId = (payload.caller_id ?? "").trim();
  if (callerId.length < 32) {
    return Response.json({ error: "caller_id required" }, { status: 400, headers: CORS_HEADERS });
  }

  const rawTitle = (payload.title ?? "").trim();
  const rawBody = (payload.body ?? "").trim();
  if (!rawBody) {
    return Response.json({ error: "body required" }, { status: 400, headers: CORS_HEADERS });
  }
  if (rawTitle.length > MAX_TITLE_CHARS || rawBody.length > MAX_BODY_CHARS) {
    return Response.json({ error: "input too long" }, { status: 400, headers: CORS_HEADERS });
  }

  const limitRes = await fetch(`${supabaseUrl}/rest/v1/rpc/check_ai_proxy_caller_limit`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
    },
    body: JSON.stringify({ p_caller_id: callerId }),
  });
  const limitText = await limitRes.text();
  if (!limitRes.ok) {
    return Response.json({ error: "rate limit failed" }, { status: 500, headers: CORS_HEADERS });
  }
  let limitStatus = "";
  try {
    limitStatus = JSON.parse(limitText) as string;
  } catch {
    return Response.json({ error: "rate limit failed" }, { status: 500, headers: CORS_HEADERS });
  }
  if (limitStatus === "caller_cap" || limitStatus === "global_cap") {
    return Response.json(
      { error: "rate_limit_exceeded", reason: limitStatus },
      { status: 429, headers: CORS_HEADERS },
    );
  }
  if (limitStatus !== "allowed") {
    return Response.json({ error: "rate limit failed" }, { status: 500, headers: CORS_HEADERS });
  }

  const title = stripIdentifying(rawTitle, MAX_TITLE_CHARS);
  const body = stripIdentifying(rawBody, MAX_BODY_CHARS);
  const userContent = `Title: ${title}\n\nBody: ${body}`;

  const anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-6",
      max_tokens: 200,
      system: REVIEW_SYSTEM,
      messages: [{ role: "user", content: userContent }],
    }),
  });

  if (!anthropicRes.ok) {
    return Response.json({ error: "upstream failed" }, { status: 502, headers: CORS_HEADERS });
  }

  const decoded = (await anthropicRes.json()) as {
    content?: Array<{ text?: string }>;
  };
  const text = decoded.content?.[0]?.text?.trim() ?? "";
  if (!text) {
    return Response.json({ error: "empty response" }, { status: 502, headers: CORS_HEADERS });
  }

  try {
    const parsed = JSON.parse(text) as { verdict?: string; note?: string };
    const verdict = parsed.verdict === "publish" ? "publish" : "pending";
    return Response.json(
      { verdict, note: typeof parsed.note === "string" ? parsed.note : "" },
      { headers: CORS_HEADERS },
    );
  } catch {
    return Response.json({ verdict: "pending", note: "Unreadable review result" }, { headers: CORS_HEADERS });
  }
});
