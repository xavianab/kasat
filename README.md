# Kasat

**Speak without fear.**

Kasat is anonymous incident reporting for survivors of gender-based violence.
It is built first for Ethiopia, with the assumption that each country or
organization runs its own deployment and keeps its own data. The survivor app
does not create an account; a tracking code minted on the handset is the link
to a report.

## Important notice

Kasat is an independent project built by Aevantic. It is not a government app
and is not affiliated with the Government of Ethiopia, the Ethiopian Federal
Police, or any government agency.

This repository is a proof-of-concept MVP in closed testing. It is **not
production-ready**. Do not use it for real incidents. Before any pilot with
real survivors, Kasat will get a professional architecture hardening pass and
an independent penetration test.

## What's in this repo

| Path | What it is | Status (from the current code) |
| --- | --- | --- |
| `kasat_mobile/` | Flutter survivor app: report intake, lookup, resources, discretionary UI (PIN / leave), and an "I'm in Danger" path | Implemented. Works offline with an on-device store. When Supabase URL and anon key are passed at build time, it syncs through narrow RPCs (`create_draft_report`, `send_draft_report`, `trigger_or_coalesce_emergency`, and related functions). |
| `kasat_dashboard/` | Next.js officer desk ("Kasat Desk"): login, station queues, case detail, notes/replies, access log, attachments | Implemented against the same Supabase project (officer auth, `list_station_reports`, dispatch transitions, realtime on `report_queue_events`). Can also run against local sample data when demo mode is enabled. |
| `supabase/` | Database schema evolution: `migrations/`, plus `schema.sql`, seeds, and Edge Functions under `functions/` | **Source of truth for the live design is `supabase/migrations/`** (shared `reports` table, stations/officers, RLS, SECURITY DEFINER RPCs, queue events). `schema.sql` is an earlier snapshot that still describes an `incidents` model and should not be treated as current without checking the migrations. |

## Privacy and security design

These claims are still reflected in the current code:

- **Client-side tracking code** - `kasat_mobile/lib/core/tracking_id.dart` mints `KST-XXXXX` with `Random.secure()` on the handset. The alphabet omits characters that are easy to confuse when read aloud (`0 O 1 I L U`).
- **Metadata scrubbing** - `kasat_mobile/lib/core/media_scrubber.dart` decodes picked images to pixels and re-encodes them, discarding EXIF/GPS and similar blocks before storage or upload.
- **Approximate location for ordinary reports** - `kasat_mobile/lib/models/approx_location.dart` supports snapped grid coordinates and Addis Ababa sub-city + landmark text. There is no constructor that accepts a raw unsnapped coordinate as the public approx location type.
- **No survivor login** - the mobile client has no Supabase Auth sign-up/sign-in for survivors. Officers authenticate in the dashboard.
- **Tiered visibility with Row Level Security** - migrations enable RLS on operational tables. Survivors talk to the database through SECURITY DEFINER RPCs rather than broad anon table reads/writes; officers read station-scoped data through authenticated RPCs and policies (see especially `supabase/migrations/20261029140000_security_hardening.sql` and later migrations).

Notes that matter for honesty:

- When Supabase is configured, the app **does** make network calls to that project. "No network calls" is no longer true for a wired build.
- The "I'm in Danger" path can stream live GPS to the backend for a limited window and opens the system dialer for the configured emergency number. That is separate from the approximate-location model used for ordinary reports.
- "No IP logging" is a property of how you deploy infrastructure and logging, not something the client can guarantee once it talks to a server.

## Running locally

### Prerequisites

- Flutter (SDK constraint in `kasat_mobile/pubspec.yaml`: `^3.13.2`) and a device or simulator
- Node.js for the dashboard
- A Supabase project if you want live sync (optional for offline-only mobile use)

### Mobile app

```bash
cd kasat_mobile
flutter pub get

# Offline / local-only (default when no Supabase defines are set):
flutter run

# Against your own Supabase project (copy the example, fill placeholders, never commit secrets):
cp dart_defines.example.json dart_defines.local.json
# edit dart_defines.local.json with YOUR project URL and anon/publishable key
flutter run --dart-define-from-file=dart_defines.local.json
```

`dart_defines.local.json` is gitignored. Use only placeholders in shared docs and examples.

Useful checks:

```bash
cd kasat_mobile
flutter test
```

### Officer dashboard

```bash
cd kasat_dashboard
npm install
cp .env.example .env.local
# fill NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY
# leave SUPABASE_SERVICE_ROLE_KEY unset in the browser env; it is server-only if you use it at all
npm run dev
```

Open the URL printed by Next.js (by default `http://localhost:3000`). Sign in with an officer account that exists in your project's Auth + `officers` roster.

To exercise the UI without a database, set `NEXT_PUBLIC_DEMO_MODE=true` in `.env.local` (see `.env.example`).

### Database

Apply migrations from `supabase/migrations/` to your own project with the Supabase CLI or dashboard. Do not use production credentials in local examples. Prefer reading the migrations over `schema.sql` when the two disagree.

## Emergency and support numbers

The Ethiopia (`ET`) resources list in
`kasat_mobile/lib/features/resources/emergency_contacts.dart` currently shows
these numbers (and other placeholder entries). Deployments must verify numbers
for their own jurisdiction before treating them as safe to dial.

| Number | Role in the app | Public source |
| --- | --- | --- |
| **991** | Default police / emergency shortcode (`KasatConfig.emergencyNumber`). Shown in Help/Resources. The "I'm in Danger" flow opens the system dialer with this number (platform confirmation still required). Entries in the resources list are still marked `verified: false`, so tapping them in Help does not dial until a deployment flips verification. | [travel.gc.ca - Ethiopia](https://travel.gc.ca/assistance/embassies-consulates/ethiopia) |
| **7711** | EWLA toll-free GBV / legal-aid hotline (`KasatConfig.ewlaGbvHotline`), listed separately from police. Independent non-profit, not government. Also `verified: false` in the resources list today. | [ewla-et.org - About us](https://ewla-et.org/about-us/) |

Other rows in the same Ethiopia list still use explicit placeholder numbers and must not be treated as real contacts.

## Security

Security is a first-order concern for a tool used by survivors of gender-based
violence. Known findings and hardening work for this MVP are tracked in
`SECURITY_TODO.md`.

If you discover a vulnerability, please report it privately to
hello@kasatapp.com rather than opening a public issue.

## License

MIT. See `LICENSE`.
