import { handleEmergencyRequest } from "./handler.ts";

Deno.serve((req) => handleEmergencyRequest(req));
