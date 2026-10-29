# Kasat

**Speak without fear.** — anonymous incident reporting for survivors, triaged by law enforcement.

Kasat is built around one constraint: the system must not hold an identity it
could be compelled to hand over. There is no survivor account, no device id, no
IP column, and no server-issued case number. A tracking code minted on the
handset is the only link between a person and their report.

```
kasat/
├── kasat_mobile/      Flutter client — survivor intake, tracking, resources   [implemented]
├── kasat_dashboard/   Next.js operator dashboard — dispatch triage            [scaffold]
└── supabase/          schema.sql — tables, RLS policies, storage, realtime
```

## kasat_mobile — running it

Requires Flutter 3.47+ and Xcode. Verified on an iPhone 17 simulator.

```bash
cd kasat_mobile
flutter pub get
flutter run                      # or: open -a Simulator && flutter run
```

The client runs with no backend. `LocalIncidentRepository` persists to the app
sandbox and ships two reference cases (`KST-4RT7Q`, `KST-9WM2K`) so the lookup
view resolves on a fresh install.

```bash
flutter test                     # unit tests: tracking ids, location snapping
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/submission_flow_test.dart
```

The integration test drives the full survivor path on a live simulator and
writes a screenshot per step into `kasat_mobile/screenshots/`.

### What the privacy claims actually do

The four guarantees on the welcome screen are enforced in code, not copy:

| Claim | Where it lives |
| --- | --- |
| Metadata scrubbed | `core/media_scrubber.dart` decodes each image to pixels and re-encodes it, discarding the EXIF/GPS block |
| Client-side case id | `core/tracking_id.dart` mints `KST-XXXXX` with `Random.secure()` before any network call |
| No exact location | `models/approx_location.dart` has no constructor that accepts an unsnapped coordinate |
| No account | there is no auth code in the client at all |

Two smaller decisions worth knowing about: the tracking alphabet omits
`0 O 1 I L U` so a code read aloud cannot round-trip into a different valid
code, and `LocalIncidentRepository.lookup` delays a flat 450 ms so response
timing does not reveal whether a code exists.

### Discretion and country routing

On first launch the app asks for a country (Ethiopia is the only live option),
a six-digit PIN, optional Face ID, and an optional home-screen icon (Notes or
Calculator). After that, every open is gated by the PIN. A **Leave** button
sits above every screen and swaps the whole navigator for a fake Notes app;
coming back always costs the PIN again.

Push copy is forced through `NotificationPolicy`. There is no constructor that
accepts arbitrary text — every notification is "You have an update."

Help lines live in `emergency_contacts.dart` / `emergency_contacts.ts`, keyed
by country code. Every shipped number is a placeholder (`verified: false`) and
will not dial. Reports carry `countryCode` so the operator portal can filter
later. An unlaunched country returns an empty list rather than another
country's numbers.

### Swapping in Supabase

`IncidentRepository` is the only seam. Implement it against Supabase, change
the binding in `main.dart`, and nothing above it moves:

```dart
final repository = SupabaseIncidentRepository(...);
await repository.init();
```

Set `KasatConfig.demoDispatch = false` at the same time — that flag walks
freshly submitted cases to `UNDER_INVESTIGATION` on a 20 s timer so realtime
updates can be exercised without a dashboard, and it must not survive contact
with real data.

## kasat_dashboard — scaffold

Not yet installed or run (Node was not present on the build machine). The
structure, design tokens, wire types, and triage/metrics components are in
place and render from `src/lib/fixtures.ts`.

```bash
cd kasat_dashboard
npm install
cp .env.example .env.local        # fill in Supabase credentials
npm run dev
```

Remaining for Part 2: Supabase Auth on `/login`, live queries and a realtime
channel on `/dispatch`, signed evidence URLs, and the interactive status
updater on the incident detail page. Each is marked with a `PART 2` comment at
the exact call site.

`src/lib/types.ts` is the schema of record shared by both apps — the status,
priority, and category codes there are the literal strings the Flutter client
serialises.

## supabase/schema.sql

Tables, enums, row level security, the evidence bucket, and realtime
publication. The policy that matters most:

```sql
create policy "anonymous lookup by tracking id"
  on incidents for select to anon
  using (tracking_id = current_setting('request.headers', true)::json ->> 'x-tracking-id');
```

Possession of a code reveals that case and nothing else. Without this scoping
the anon key would enumerate every report in the table.

## Known gaps

- Emergency numbers in `features/resources/emergency_contacts.dart` are
  placeholders. Kasat is meant to be deployed per jurisdiction and a wrong
  number there is worse than no number.
- Scrubbed images are re-encoded as PNG because `dart:ui` ships no JPEG
  encoder, so attachments are larger than the originals.
- "No IP logging" is a property of the deployment, not the client. It holds
  today only because the MVP makes no network calls at all.

## Project status

Kasat is an early-stage **proof-of-concept MVP**, built to demonstrate the
concept and support grant applications. The survivor client (`kasat_mobile`)
is implemented; the operator dashboard (`kasat_dashboard`) is a scaffold.

This code is **not yet production-ready and is not deployed to real users.**
Before any pilot with real survivors, Kasat will undergo:

- a full architecture hardening pass by professional engineers, and
- an independent third-party security review / penetration test.

Treat the current code as a reference implementation of the concept, not a
system to point real reporters at.

## Security

Security is a first-order concern for a tool used by survivors of gender-based
violence. The codebase has had an internal security audit, and known findings
are tracked in `SECURITY_TODO.md`.

If you discover a vulnerability, please report it privately to
hello@kasatapp.com rather than opening a public issue.
