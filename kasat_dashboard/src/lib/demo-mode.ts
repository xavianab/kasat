/**
 * Local sample-data mode for the officer desk.
 *
 * NEXT_PUBLIC_DEMO_MODE is ignored (and the production build fails) when
 * NODE_ENV is production, so a misconfigured deploy cannot ship fixture cases.
 */
export function isDemoModeEnabled(): boolean {
  if (process.env.NODE_ENV === "production") return false;
  return process.env.NEXT_PUBLIC_DEMO_MODE === "true";
}
