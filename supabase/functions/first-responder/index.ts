import { handleFirstResponderRequest } from "./handler.ts";

Deno.serve((req) =>
  handleFirstResponderRequest(req, {
    env: {
      AI_RESPONDER_ENABLED: Deno.env.get("AI_RESPONDER_ENABLED") ?? undefined,
      ANTHROPIC_API_KEY: Deno.env.get("ANTHROPIC_API_KEY") ?? undefined,
      ANTHROPIC_MODEL: Deno.env.get("ANTHROPIC_MODEL") ?? undefined,
      SUPABASE_URL: Deno.env.get("SUPABASE_URL") ?? undefined,
      SUPABASE_SERVICE_ROLE_KEY: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? undefined,
      FIRST_RESPONDER_HOOK_SECRET: Deno.env.get("FIRST_RESPONDER_HOOK_SECRET") ?? undefined,
    },
  })
);
