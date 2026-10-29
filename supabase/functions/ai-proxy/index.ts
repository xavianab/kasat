// Server-side Anthropic proxy. The mobile binary never ships an API key.
// Identifying details are stripped before the model sees the text.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const VENT_SYSTEM = `You are Kasat, a quiet companion on a private board where people write what
they cannot say out loud. You are not a therapist, not a crisis line, and not
a doctor.

Write like a caring friend texting back. Two to four short sentences.
Do not say you are sorry to hear that. Do not diagnose. Do not give
instructions unless the writer asked for them. Do not use the words
"as an AI" or "language model". Do not ask a list of clinical questions.
Acknowledge what they wrote. Leave the door open. That is enough.`;

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

function stripIdentifying(text: string): string {
  return text
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, "[redacted-email]")
    .replace(/\b(?:\+?251|0)?[79]\d{8}\b/g, "[redacted-phone]")
    .replace(/\b\+?\d[\d\s().-]{7,}\d\b/g, "[redacted-number]")
    .slice(0, 2000);
}

type ProxyBody = {
  kind?: "vent" | "review";
  body?: string;
  title?: string;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405, headers: CORS_HEADERS });
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
  if (!apiKey) {
    return Response.json({ error: "Review service is not configured" }, { status: 503, headers: CORS_HEADERS });
  }

  let payload: ProxyBody;
  try {
    payload = (await req.json()) as ProxyBody;
  } catch {
    return Response.json({ error: "Invalid JSON" }, { status: 400, headers: CORS_HEADERS });
  }

  const kind = payload.kind === "review" ? "review" : "vent";
  const body = stripIdentifying((payload.body ?? "").trim());
  const title = stripIdentifying((payload.title ?? "").trim());
  if (!body) {
    return Response.json({ error: "body required" }, { status: 400, headers: CORS_HEADERS });
  }

  const userContent =
    kind === "review" ? `Title: ${title}\n\nBody: ${body}` : body;

  const anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-6",
      max_tokens: kind === "review" ? 200 : 220,
      system: kind === "review" ? REVIEW_SYSTEM : VENT_SYSTEM,
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

  if (kind === "review") {
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
  }

  return Response.json({ text }, { headers: CORS_HEADERS });
});
