# Phase 2 roadmap

Items explicitly deferred from the Batch 2 MVP. One line each, so a funder or a new engineer can see why they are not in the build.

1. **Background / locked-screen shake detection on iOS** — the OS does not give third-party apps accelerometer access while the app is not in the foreground. An Android-only experiment can be tried later; it is not in this batch.
2. **True instant network-change detection while the app is fully closed** — iOS Background App Refresh and Android WorkManager are best-effort and may be delayed or skipped. This batch checks on open and on resume, and says so in the UI.
3. **Real translations for Oromifa, Tigrinya, Somali, and Afar** — the picker lists all six languages. Only English and Amharic have copy. Adding one of the other four is a JSON file drop, not an architecture change.
4. **Automatic join of phone/email identity to report content in the normal UI** — identity lives in a separate encrypted store with no foreign key to incidents or Vent posts. A legal-request process is a documented exception, not a field on the triage screen.
