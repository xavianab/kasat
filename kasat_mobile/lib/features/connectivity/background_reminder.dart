/// STUB: periodic connectivity check while the app is fully closed.
///
/// iOS does not let a third-party app instantly notice that data dropped when
/// it is not running. Android WorkManager / iOS Background App Refresh can
/// check every few hours, and the OS may delay or skip that work.
///
/// This batch implements the reliable layer: check on open and on resume.
/// Wiring Background App Refresh / WorkManager is Phase 2 — see
/// PHASE2_ROADMAP.md. Do not promise instant detection in UI copy.
class BackgroundConnectivityReminder {
  const BackgroundConnectivityReminder();

  // STUB: register a periodic task here when background modes are provisioned.
  Future<void> register() async {}
}
