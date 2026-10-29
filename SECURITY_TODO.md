# Security TODO

Batch 2 is the first time Kasat stores personal data (a phone number or email for accountability, and a trusted-contact number for SMS duress). This file is part of the MVP's honest posture — not a backlog nicety.

Before any real-world or production use:

1. **Encryption-at-rest** — AES keys for identity and duress currently live in the same SharedPreferences file as the ciphertext. Move them to the iOS Keychain / Android Keystore.
2. **Access logging** — any internal process that decrypts a phone or email (legal request, abuse-pattern review) must write an audit record. That process must not be a column on the normal report view.
3. **Data retention policy** — written rules for how long identity handles and trusted-contact numbers are kept, and how they are wiped.
4. **Hotline numbers** — `emergency_contacts.dart` still holds placeholders with `verified: false`. Replace and verify before anyone is invited to dial from the app.
5. **SMS duress** — this MVP opens the system SMS composer with a pre-filled body. iOS will not send SMS with no UI. Silent send on Android would need `SEND_SMS` and a threat-model review.
6. **AI companion** — the Anthropic key is a compile-time `--dart-define`. Never ship a key in the bundle. Prefer a server-side proxy before production.
7. **No analytics, no crash SDKs, no third-party trackers.** Keep it that way.
