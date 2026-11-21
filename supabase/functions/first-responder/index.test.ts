import { redactSurvivorText } from "./redact.ts";
import {
  FALLBACK_EN,
  MAX_AUTOMATED_REPLIES_PER_HOUR,
  callAnthropic,
  fallbackReply,
  handleFirstResponderRequest,
  parseAutomatedReplyCount,
} from "./handler.ts";

const HOOK = "hook-secret-for-tests-32chars!!";
const CASE_ID = "11111111-1111-4111-8111-111111111111";

function responderRequest(text = "He hurt me and I need help from the police team please.") {
  return new Request("https://example.test/functions/v1/first-responder", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-kasat-responder-secret": HOOK,
    },
    body: JSON.stringify({
      case_id: CASE_ID,
      text,
      source: "message",
    }),
  });
}

const baseEnv = {
  AI_RESPONDER_ENABLED: "true",
  ANTHROPIC_API_KEY: "test-key",
  FIRST_RESPONDER_HOOK_SECRET: HOOK,
  SUPABASE_URL: "https://example.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
};

Deno.test("redact removes phone numbers, emails, and address-like strings", () => {
  const raw =
    "He called +251 911 234 567 and emailed abuser@example.com. House no 12, Kebele 05 near Bole Road.";
  const out = redactSurvivorText(raw);
  if (out.includes("911") || out.includes("+251")) {
    throw new Error(`phone leaked: ${out}`);
  }
  if (out.toLowerCase().includes("example.com") || out.includes("@")) {
    throw new Error(`email leaked: ${out}`);
  }
  if (/house\s*no/i.test(out) || /kebele\s*05/i.test(out)) {
    throw new Error(`address leaked: ${out}`);
  }
  if (!out.includes("[redacted-phone]") || !out.includes("[redacted-email]")) {
    throw new Error(`expected redaction markers: ${out}`);
  }
});

Deno.test("redact keeps narrative text that is not identifying", () => {
  const raw =
    "He threatened me at work yesterday and I am scared to go back. Please help.";
  const out = redactSurvivorText(raw);
  if (!out.includes("threatened me at work")) {
    throw new Error(`narrative changed too much: ${out}`);
  }
});

Deno.test("fallbackReply picks Amharic when Ethiopic script is present", () => {
  const am = fallbackReply("እባክዎ እርዱኝ እሱ ይደውላል");
  if (!am.includes("እናምንዎታለን")) {
    throw new Error(`expected Amharic fallback, got ${am}`);
  }
  const en = fallbackReply("Please help me he keeps calling");
  if (en !== FALLBACK_EN) {
    throw new Error(`expected English fallback`);
  }
});

Deno.test("callAnthropic returns null on timeout or failure", async () => {
  const result = await callAnthropic({
    apiKey: "test-key",
    model: "claude-test",
    userText: "Please help.",
    timeoutMs: 50,
    fetchFn: () =>
      new Promise((_, reject) => {
        setTimeout(() => reject(new Error("timeout")), 200);
      }),
  });
  if (result.text !== null) {
    throw new Error(`expected null text on failure, got ${result.text}`);
  }
  if (!result.error?.message) {
    throw new Error("expected error message on failure");
  }
});

Deno.test("callAnthropic logs status type and message without request body", async () => {
  const result = await callAnthropic({
    apiKey: "test-key",
    model: "claude-haiku-5-5",
    userText: "survivor secret text must never appear in logs",
    fetchFn: async () =>
      new Response(
        JSON.stringify({
          type: "error",
          error: { type: "invalid_request_error", message: "credit balance too low" },
        }),
        { status: 400 },
      ),
  });
  if (result.text !== null) throw new Error("expected null text");
  if (result.error?.status !== 400) throw new Error(`expected status 400, got ${result.error?.status}`);
  if (result.error?.type !== "invalid_request_error") {
    throw new Error(`expected type invalid_request_error, got ${result.error?.type}`);
  }
  if (result.error?.message !== "credit balance too low") {
    throw new Error(`expected credit message, got ${result.error?.message}`);
  }
  const dumped = JSON.stringify(result.error);
  if (dumped.includes("survivor secret")) {
    throw new Error("survivor text leaked into error object");
  }
});

Deno.test("handler inserts fallback when Anthropic fails", async () => {
  const rpcCalls: Array<{ url: string; body: string }> = [];

  const res = await handleFirstResponderRequest(responderRequest(), {
    env: baseEnv,
    fetchFn: async (input, init) => {
      const url = String(input);
      const body = typeof init?.body === "string" ? init.body : "";
      rpcCalls.push({ url, body });
      if (url.includes("/rpc/count_automated_replies_last_hour")) {
        return new Response("0", { status: 200 });
      }
      if (url.includes("api.anthropic.com")) {
        return new Response("upstream down", { status: 500 });
      }
      if (url.includes("/rpc/send_automated_reply")) {
        const parsed = JSON.parse(body) as { p_body?: string };
        if (parsed.p_body !== FALLBACK_EN) {
          throw new Error(`expected fallback body, got ${parsed.p_body}`);
        }
        return new Response(JSON.stringify("22222222-2222-4222-8222-222222222222"), {
          status: 200,
        });
      }
      throw new Error(`unexpected ${url}`);
    },
  });

  if (res.status !== 200) {
    throw new Error(`expected 200, got ${res.status} ${await res.text()}`);
  }
  const json = (await res.json()) as { ok?: boolean; fallback?: boolean };
  if (!json.ok || !json.fallback) {
    throw new Error(`expected ok+fallback, got ${JSON.stringify(json)}`);
  }
  if (!rpcCalls.some((c) => c.url.includes("send_automated_reply"))) {
    throw new Error("send_automated_reply was not called");
  }
});

Deno.test("parseAutomatedReplyCount fails closed on garbage", () => {
  if (parseAutomatedReplyCount("0") !== 0) throw new Error("expected 0");
  if (parseAutomatedReplyCount("3") !== 3) throw new Error("expected 3");
  if (parseAutomatedReplyCount('"2"') !== 2) throw new Error("expected 2 from JSON string");
  if (parseAutomatedReplyCount("nope") !== null) throw new Error("expected null");
});

Deno.test("fallback replies count toward the 3-per-hour cap", async () => {
  let stored = 0;
  let anthropicCalls = 0;
  let insertCalls = 0;

  const fetchFn: typeof fetch = async (input, init) => {
    const url = String(input);
    if (url.includes("/rpc/count_automated_replies_last_hour")) {
      return new Response(JSON.stringify(stored), { status: 200 });
    }
    if (url.includes("api.anthropic.com")) {
      anthropicCalls += 1;
      return new Response("upstream down", { status: 500 });
    }
    if (url.includes("/rpc/send_automated_reply")) {
      const body = typeof init?.body === "string" ? init.body : "";
      const parsed = JSON.parse(body) as { p_body?: string };
      if (parsed.p_body !== FALLBACK_EN) {
        throw new Error(`expected fallback body, got ${parsed.p_body}`);
      }
      if (stored >= MAX_AUTOMATED_REPLIES_PER_HOUR) {
        return new Response(JSON.stringify({ message: "automated_rate_limited" }), {
          status: 400,
        });
      }
      insertCalls += 1;
      stored += 1;
      return new Response(JSON.stringify(crypto.randomUUID()), { status: 200 });
    }
    throw new Error(`unexpected ${url}`);
  };

  for (let i = 0; i < MAX_AUTOMATED_REPLIES_PER_HOUR; i++) {
    const res = await handleFirstResponderRequest(responderRequest(), {
      env: baseEnv,
      fetchFn,
    });
    const json = (await res.json()) as { ok?: boolean; fallback?: boolean };
    if (!json.ok || !json.fallback) {
      throw new Error(`insert ${i + 1} should be fallback ok, got ${JSON.stringify(json)}`);
    }
  }

  if (stored !== MAX_AUTOMATED_REPLIES_PER_HOUR || insertCalls !== MAX_AUTOMATED_REPLIES_PER_HOUR) {
    throw new Error(`expected ${MAX_AUTOMATED_REPLIES_PER_HOUR} stored fallbacks, got ${stored}`);
  }

  const blocked = await handleFirstResponderRequest(responderRequest(), {
    env: baseEnv,
    fetchFn,
  });
  const blockedJson = (await blocked.json()) as { skipped?: boolean; reason?: string };
  if (!blockedJson.skipped || blockedJson.reason !== "rate_limited") {
    throw new Error(`4th fallback must be rate_limited, got ${JSON.stringify(blockedJson)}`);
  }
  if (insertCalls !== MAX_AUTOMATED_REPLIES_PER_HOUR) {
    throw new Error("4th request must not insert another automated reply");
  }
  if (anthropicCalls !== MAX_AUTOMATED_REPLIES_PER_HOUR) {
    throw new Error("Anthropic must not run after the hourly cap is hit");
  }
  if (stored !== MAX_AUTOMATED_REPLIES_PER_HOUR) {
    throw new Error(`cap exceeded: stored=${stored}`);
  }
});
