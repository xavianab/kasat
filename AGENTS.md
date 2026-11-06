# Kasat Rules

- Never break existing features. Before finishing ANY task in `kasat_mobile`, run `flutter analyze` (no errors) and `flutter test` (all pass). In `kasat_dashboard`, run the tests and a type check.
- Never run `npm run build` while the dev server runs. Never start/restart dev servers. Never commit.
- Dev Supabase only (`vbpwhruoyibbivpchmaf`). Database changes = one new migration, shown before applying.
- Never change RLS, claim rules or evidence rules without being asked.
- UI text: plain short sentences, no em dashes or en dashes.
- Every screen must work with the keyboard open, at the largest font size, in Amharic, on a 360px-wide phone, and in light and dark mode.
