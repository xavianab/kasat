import {
  applyEmergencySoftLimits,
  clientIp,
  handleEmergencyRequest,
} from "./handler.ts";

Deno.test("clientIp returns empty when forwarding headers are absent", () => {
  const req = new Request("https://example.test/emergency-alert", { method: "POST" });
  if (clientIp(req) !== "") {
    throw new Error(`expected empty IP, got ${clientIp(req)}`);
  }
});

Deno.test("missing IP is accepted and still reaches emergency RPC", async () => {
  const rpcCalls: string[] = [];
  const logs: string[] = [];

  const req = new Request("https://example.test/functions/v1/emergency-alert", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      p_device_secret: "abcdefghijklmnopqrstuvwxyz0123456789ABCD",
      p_description: "Urgent silent alert needing help with enough characters here.",
    }),
  });

  const res = await handleEmergencyRequest(req, {
    env: {
      SUPABASE_URL: "https://example.supabase.co",
      SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
    },
    log: (message) => logs.push(message),
    fetchFn: async (input) => {
      const url = String(input);
      rpcCalls.push(url);
      if (url.includes("check_emergency_ip_limit")) {
        throw new Error("IP limiter must not run when IP is missing");
      }
      if (url.includes("check_emergency_global_cap")) {
        return new Response(JSON.stringify("allowed"), { status: 200 });
      }
      if (url.includes("trigger_or_coalesce_emergency")) {
        return new Response(
          JSON.stringify({ tracking_code: "KST-ABCDE", dispatch_status: "new" }),
          { status: 200 },
        );
      }
      throw new Error(`unexpected ${url}`);
    },
  });

  if (res.status !== 200) {
    throw new Error(`expected 200, got ${res.status} ${await res.text()}`);
  }
  if (!rpcCalls.some((u) => u.includes("trigger_or_coalesce_emergency"))) {
    throw new Error("emergency RPC must run when IP is missing");
  }
  if (!logs.some((m) => m.includes("client IP missing"))) {
    throw new Error("missing-IP path must log");
  }
});

Deno.test("forged X-Forwarded-For / CF-Connecting-IP still accepts and cannot starve another caller", async () => {
  const ipBuckets = new Map<string, number>();
  const victimsIp = "198.51.100.10";
  ipBuckets.set(victimsIp, 0);

  const forgedReq = new Request("https://example.test/functions/v1/emergency-alert", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "cf-connecting-ip": "203.0.113.99",
      "x-forwarded-for": "198.51.100.1, 203.0.113.99",
    },
    body: JSON.stringify({
      p_device_secret: "forged-attacker-secret-at-least-32-chars!!",
      p_description: "Urgent silent alert needing help with enough characters here.",
    }),
  });

  const res = await handleEmergencyRequest(forgedReq, {
    env: {
      SUPABASE_URL: "https://example.supabase.co",
      SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
    },
    log: () => {},
    fetchFn: async (input, init) => {
      const url = String(input);
      if (url.includes("check_emergency_ip_limit")) {
        const body = JSON.parse(String(init?.body ?? "{}")) as { p_ip?: string };
        const ip = body.p_ip ?? "";
        // Forged IP must not increment the victim's real bucket.
        if (ip === victimsIp) {
          throw new Error("forged request must not touch victim IP bucket");
        }
        ipBuckets.set(ip, (ipBuckets.get(ip) ?? 0) + 1);
        return new Response("null", { status: 200 });
      }
      if (url.includes("check_emergency_global_cap")) {
        return new Response(JSON.stringify("allowed"), { status: 200 });
      }
      if (url.includes("trigger_or_coalesce_emergency")) {
        return new Response(
          JSON.stringify({ tracking_code: "KST-FORGE", dispatch_status: "new" }),
          { status: 200 },
        );
      }
      throw new Error(`unexpected ${url}`);
    },
  });

  if (res.status !== 200) {
    throw new Error(`forged header request must be accepted, got ${res.status}`);
  }
  if ((ipBuckets.get(victimsIp) ?? 0) !== 0) {
    throw new Error("victim IP bucket must remain untouched");
  }
  if ((ipBuckets.get("203.0.113.99") ?? 0) !== 1) {
    throw new Error("forged IP should only consume its own best-effort bucket");
  }
});

Deno.test("over flood threshold the alert is still accepted and flood_suspected is recorded", async () => {
  const logs: string[] = [];
  let floodRecorded = false;
  let emergencyCalled = false;

  const soft = await applyEmergencySoftLimits({
    ip: "",
    supabaseUrl: "https://example.supabase.co",
    serviceKey: "service-role-key",
    log: (message) => logs.push(message),
    fetchFn: async (input) => {
      const url = String(input);
      if (url.includes("check_emergency_global_cap")) {
        floodRecorded = true;
        return new Response(JSON.stringify("flood_suspected"), { status: 200 });
      }
      throw new Error(`unexpected ${url}`);
    },
  });

  if (!soft.floodSuspected || !floodRecorded) {
    throw new Error("expected flood_suspected soft signal");
  }
  if (!logs.some((m) => m.includes("flood_suspected"))) {
    throw new Error("expected flood warning log");
  }

  const req = new Request("https://example.test/functions/v1/emergency-alert", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      p_device_secret: "abcdefghijklmnopqrstuvwxyz0123456789ABCD",
      p_description: "Urgent silent alert needing help with enough characters here.",
    }),
  });

  const res = await handleEmergencyRequest(req, {
    env: {
      SUPABASE_URL: "https://example.supabase.co",
      SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
    },
    log: (message) => logs.push(message),
    fetchFn: async (input) => {
      const url = String(input);
      if (url.includes("check_emergency_global_cap")) {
        return new Response(JSON.stringify("flood_suspected"), { status: 200 });
      }
      if (url.includes("trigger_or_coalesce_emergency")) {
        emergencyCalled = true;
        return new Response(
          JSON.stringify({ tracking_code: "KST-FLOOD", dispatch_status: "new" }),
          { status: 200 },
        );
      }
      throw new Error(`unexpected ${url}`);
    },
  });

  if (res.status !== 200 || !emergencyCalled) {
    throw new Error("flood_suspected must still dispatch emergency");
  }
});
