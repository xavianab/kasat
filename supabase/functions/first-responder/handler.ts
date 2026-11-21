// Trauma-informed AI first responder for survivor reports and messages.
// Receives only case_id + text. Never name, phone, location, photo, device id, or case code.

import { looksAmharic, redactSurvivorText } from "./redact.ts";

export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-kasat-responder-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export const SYSTEM_PROMPT = `You are Kasat support (automated), a calm trauma-informed first responder for survivors of gender-based violence in Ethiopia.
You are not a human and not a police officer. Never claim to be either.
Always speak as "we" (Kasat support), never "I". In English use we/us/our. In Amharic use እኛ forms (for example እናምንሻለን and እናመሰግናለን), never first person singular like አመሰግናለሁ.
Reply in the same language the survivor wrote in (Amharic or English).
Write 3 to 5 short sentences. Use plain words. Do not use dashes (no em dash, en dash, or hyphenated asides).
When writing Amharic: always use the feminine form for the survivor, keep sentences short and natural, and do not start with እባክሽ.
You must:
- Tell her she is believed and it is not her fault.
- Explain simply what happens next: a trained officer from the police team for her area will see the report, and her identity stays hidden unless she chooses.
- Point to help: if she is in danger now, call 991; EWLA free hotline 7711.
You must never:
- Promise outcomes, legal results, or timelines.
- Ask for her name, address, phone number, or family details.
- Give medical or legal advice.
- Mention case codes, device ids, photos, or locations.`;

export const FALLBACK_EN =
  "Thank you for telling us. You are believed. Your report has reached the police team for your area. If you are in danger now, call 991, or 7711 for free support.";

export const FALLBACK_AM =
  "ስለነገሩን እናመሰግናለን። እናምንሻለን። ሪፖርትሽ የአካባቢሽ የፖሊስ ቡድን ደርሷል። አሁን አደጋ ላይ ከሆንሽ 991 ደውዪ፣ ወይም ነፃ ድጋፍ ለማግኘት 7711።";

export function fallbackReply(sourceText: string): string {
  return looksAmharic(sourceText) ? FALLBACK_AM : FALLBACK_EN;
}

/** Hard cap: every automated insert counts, including fallback replies. */
export const MAX_AUTOMATED_REPLIES_PER_HOUR = 3;

export function parseAutomatedReplyCount(raw: string): number | null {
  let value: unknown = raw;
  try {
    value = JSON.parse(raw);
  } catch {
    // PostgREST may return a bare number string.
  }
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n) || n < 0) return null;
  return Math.floor(n);
}

export type ResponderEnv = {
  AI_RESPONDER_ENABLED?: string;
  ANTHROPIC_API_KEY?: string;
  ANTHROPIC_MODEL?: string;
  SUPABASE_URL?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  FIRST_RESPONDER_HOOK_SECRET?: string;
};

export type ResponderBody = {
  case_id?: string;
  text?: string;
  source?: string;
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const ANTHROPIC_TIMEOUT_MS = 8000;

export function hookAuthorized(req: Request, env: ResponderEnv): boolean {
  const expected = env.FIRST_RESPONDER_HOOK_SECRET ?? "";
  if (!expected) return false;
  const presented = req.headers.get("x-kasat-responder-secret") ?? "";
  return presented === expected;
}

export function responderEnabled(env: ResponderEnv): boolean {
  const raw = (env.AI_RESPONDER_ENABLED ?? "true").trim().toLowerCase();
  return raw !== "false" && raw !== "0" && raw !== "off";
}

async function rpcJson(
  supabaseUrl: string,
  serviceKey: string,
  fn: string,
  body: Record<string, unknown>,
  fetchFn: typeof fetch,
): Promise<{ ok: boolean; status: number; text: string }> {
  const res = await fetchFn(`${supabaseUrl}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  return { ok: res.ok, status: res.status, text };
}

export type AnthropicCallResult = {
  text: string | null;
  /** Safe to log. Never includes survivor text or the API key. */
  error?: {
    status?: number;
    type?: string;
    message: string;
  };
};

/** Parse Anthropic error JSON without retaining any request content. */
export function parseAnthropicErrorBody(
  status: number,
  bodyText: string,
): { status: number; type?: string; message: string } {
  try {
    const parsed = JSON.parse(bodyText) as {
      type?: string;
      error?: { type?: string; message?: string };
      message?: string;
    };
    const type = parsed.error?.type ?? parsed.type;
    const message =
      (typeof parsed.error?.message === "string" && parsed.error.message) ||
      (typeof parsed.message === "string" && parsed.message) ||
      bodyText.slice(0, 200) ||
      `Anthropic HTTP ${status}`;
    return { status, type, message: message.slice(0, 300) };
  } catch {
    return {
      status,
      message: bodyText.trim().slice(0, 200) || `Anthropic HTTP ${status}`,
    };
  }
}

export async function callAnthropic(opts: {
  apiKey: string;
  model: string;
  userText: string;
  fetchFn?: typeof fetch;
  timeoutMs?: number;
}): Promise<AnthropicCallResult> {
  const fetchFn = opts.fetchFn ?? fetch;
  const timeoutMs = opts.timeoutMs ?? ANTHROPIC_TIMEOUT_MS;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetchFn("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": opts.apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: opts.model,
        // Haiku 5.5 enables adaptive thinking by default; thinking tokens
        // count toward max_tokens. A low budget (e.g. 400) often stops after
        // a thinking block with no text. Disable thinking for this short
        // trauma-informed reply, and keep enough room for 3–5 sentences.
        max_tokens: 800,
        thinking: { type: "disabled" },
        system: SYSTEM_PROMPT,
        messages: [{ role: "user", content: opts.userText }],
      }),
      signal: controller.signal,
    });
    const bodyText = await res.text();
    if (!res.ok) {
      return { text: null, error: parseAnthropicErrorBody(res.status, bodyText) };
    }
    let decoded: {
      content?: Array<{ type?: string; text?: string; refusal?: string }>;
      stop_reason?: string | null;
      model?: string;
    };
    try {
      decoded = JSON.parse(bodyText) as typeof decoded;
    } catch {
      return {
        text: null,
        error: { status: res.status, type: "invalid_response", message: "Anthropic returned non-JSON" },
      };
    }
    const blocks = Array.isArray(decoded.content) ? decoded.content : [];
    // Prefer explicit text blocks; fall back to any block with a text field
    // (thinking / tool_use first would make content[0].text empty).
    const textBlock =
      blocks.find((b) => b?.type === "text" && typeof b.text === "string") ??
      blocks.find((b) => typeof b?.text === "string");
    const text = textBlock?.text?.trim() ?? "";
    if (!text) {
      const refusal = blocks.find((b) => b?.type === "refusal")?.refusal?.slice(0, 120);
      const summary = blocks
        .map((b) => `${b?.type ?? "unknown"}:${typeof b?.text === "string" ? b.text.length : 0}`)
        .join(",") || "no_blocks";
      return {
        text: null,
        error: {
          status: res.status,
          type: refusal ? "refusal" : "empty_response",
          message: [
            "Anthropic returned empty content",
            `stop=${decoded.stop_reason ?? "null"}`,
            `model=${decoded.model ?? opts.model}`,
            `blocks=${summary}`,
            refusal ? `refusal=${refusal}` : null,
          ]
            .filter(Boolean)
            .join("; ")
            .slice(0, 300),
        },
      };
    }
    // Soft-guard: drop accidental dashes the model may emit.
    return { text: text.replace(/\u2014|\u2013/g, ",").slice(0, 2000) };
  } catch (err) {
    const name = err instanceof Error ? err.name : "Error";
    const message =
      name === "AbortError"
        ? `Anthropic timed out after ${timeoutMs}ms`
        : "Anthropic request failed";
    return { text: null, error: { type: name, message } };
  } finally {
    clearTimeout(timer);
  }
}

export async function handleFirstResponderRequest(
  req: Request,
  deps: {
    env: ResponderEnv;
    fetchFn?: typeof fetch;
    log?: (message: string, data?: Record<string, unknown>) => void;
  },
): Promise<Response> {
  const fetchFn = deps.fetchFn ?? fetch;
  const log = deps.log ?? ((message, data) => console.log(message, data ?? {}));

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405, headers: CORS_HEADERS });
  }
  if (!hookAuthorized(req, deps.env)) {
    return Response.json({ error: "Unauthorized" }, { status: 401, headers: CORS_HEADERS });
  }
  if (!responderEnabled(deps.env)) {
    return Response.json({ skipped: true, reason: "disabled" }, { headers: CORS_HEADERS });
  }

  const supabaseUrl = deps.env.SUPABASE_URL ?? "";
  const serviceKey = deps.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
  if (!supabaseUrl || !serviceKey) {
    return Response.json({ error: "Server configuration missing" }, { status: 500, headers: CORS_HEADERS });
  }

  let payload: ResponderBody;
  try {
    payload = (await req.json()) as ResponderBody;
  } catch {
    return Response.json({ error: "Invalid JSON" }, { status: 400, headers: CORS_HEADERS });
  }

  const caseId = (payload.case_id ?? "").trim();
  const source = (payload.source ?? "").trim();
  const rawText = (payload.text ?? "").trim();
  if (!UUID_RE.test(caseId)) {
    return Response.json({ error: "Invalid case_id" }, { status: 400, headers: CORS_HEADERS });
  }
  if (source !== "report" && source !== "message") {
    return Response.json({ error: "Invalid source" }, { status: 400, headers: CORS_HEADERS });
  }
  if (!rawText) {
    return Response.json({ error: "text required" }, { status: 400, headers: CORS_HEADERS });
  }

  // Rate limit before Anthropic. Counts every automated reply, including fallbacks.
  const countRes = await rpcJson(
    supabaseUrl,
    serviceKey,
    "count_automated_replies_last_hour",
    { p_case_id: caseId },
    fetchFn,
  );
  if (!countRes.ok) {
    log("first-responder count failed", { status: countRes.status });
    return Response.json({ error: "rate check failed" }, { status: 500, headers: CORS_HEADERS });
  }
  const recent = parseAutomatedReplyCount(countRes.text);
  if (recent === null) {
    log("first-responder count unreadable", { body: countRes.text.slice(0, 80) });
    return Response.json({ error: "rate check failed" }, { status: 500, headers: CORS_HEADERS });
  }
  if (recent >= MAX_AUTOMATED_REPLIES_PER_HOUR) {
    return Response.json({ skipped: true, reason: "rate_limited" }, { headers: CORS_HEADERS });
  }

  const redacted = redactSurvivorText(rawText);
  if (!redacted) {
    return Response.json({ skipped: true, reason: "empty_after_redact" }, { headers: CORS_HEADERS });
  }

  const apiKey = (deps.env.ANTHROPIC_API_KEY ?? "").trim();
  const model = (deps.env.ANTHROPIC_MODEL ?? "claude-haiku-5-5").trim() || "claude-haiku-5-5";
  let reply: string | null = null;
  let anthropicFailure: {
    status?: number | null;
    type?: string | null;
    message: string;
  } | null = null;
  if (!apiKey) {
    anthropicFailure = {
      status: null,
      type: "missing_api_key",
      message: "ANTHROPIC_API_KEY is missing or empty",
    };
    log("first-responder Anthropic skipped", {
      reason: "missing_api_key",
      model,
    });
  } else {
    const result = await callAnthropic({
      apiKey,
      model,
      userText: redacted,
      fetchFn,
    });
    reply = result.text;
    if (result.error) {
      anthropicFailure = {
        status: result.error.status ?? null,
        type: result.error.type ?? null,
        message: result.error.message,
      };
      log("first-responder Anthropic failed", {
        status: anthropicFailure.status,
        type: anthropicFailure.type,
        message: anthropicFailure.message,
        model,
      });
    }
  }
  if (!reply) {
    log("first-responder using fallback", { case_id: caseId, model });
    reply = fallbackReply(rawText);
  }

  const insertRes = await rpcJson(
    supabaseUrl,
    serviceKey,
    "send_automated_reply",
    { p_case_id: caseId, p_body: reply },
    fetchFn,
  );
  if (!insertRes.ok) {
    if (insertRes.text.includes("automated_rate_limited")) {
      return Response.json({ skipped: true, reason: "rate_limited" }, { headers: CORS_HEADERS });
    }
    log("first-responder insert failed", { status: insertRes.status, body: insertRes.text.slice(0, 200) });
    return Response.json({ error: "insert failed" }, { status: 500, headers: CORS_HEADERS });
  }

  const usedFallback = reply === FALLBACK_EN || reply === FALLBACK_AM;
  return Response.json(
    {
      ok: true,
      fallback: usedFallback,
      // Safe diagnostic only: status/type/message. Never survivor text or API key.
      ...(usedFallback && anthropicFailure
        ? {
            anthropic_error: {
              status: anthropicFailure.status,
              type: anthropicFailure.type,
              message: anthropicFailure.message,
              model,
            },
          }
        : {}),
    },
    { headers: CORS_HEADERS },
  );
}
