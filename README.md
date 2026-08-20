# DriveBiryani — Unified Multi-Account Google Drive Search

A Flutter app that links multiple Google accounts (personal, work, school, ...) via OAuth and lets you search all of their Google Drives from one screen — results merged client-side, at zero recurring cost.

## Why

Google Drive's search only ever covers one signed-in account at a time. This links as many accounts as you want and fans a single query out to all of them in parallel.

## Architecture

Entirely client-side, no custom backend:

```
Flutter App
 ├─ Firebase Auth (Spark plan)   → gates app access, one identity for "you"
 ├─ Cloud Firestore (Spark plan) → non-sensitive metadata only:
 │                                  which account emails are linked, display name, last synced
 ├─ flutter_secure_storage       → each linked account's refresh_token,
 │                                  OS keychain/keystore-encrypted, never in Firestore
 ├─ flutter_appauth              → OAuth2 Authorization Code + PKCE per Google account,
 │                                  scope = drive.metadata.readonly
 └─ Direct HTTPS calls           → oauth2.googleapis.com/token (refresh)
                                    www.googleapis.com/drive/v3/files (search)
                                    called straight from the app, in parallel per account,
                                    results merged client-side
```

No Cloud Functions: Android/Desktop-type OAuth clients don't carry a client secret worth protecting server-side, so there's nothing a backend would need to guard — sidestepping the Blaze (billing) plan entirely.

## Tech Stack

- Flutter
- `firebase_core`, `firebase_auth`, `cloud_firestore` (Spark/free plan)
- `flutter_appauth` — OAuth2 + PKCE, multi-account
- `flutter_secure_storage` — encrypted local token storage

## Trade-off

The OAuth consent screen stays in **Testing** status (free, unverified) rather than paying for a CASA security audit to reach Production. That means each linked account's refresh token expires after ~7 days, and the app prompts a quick reconnect when that happens. Up to 100 named test users are supported.

## Getting Started

```bash
flutter pub get
flutter run --dart-define=OAUTH_CLIENT_SECRET=<your-client-secret>
```

You'll need your own Google Cloud project with the Drive API enabled and an OAuth client configured — see `PLAN.md` for the full setup walkthrough (OAuth consent screen, test users, Firebase project on the Spark plan).

`lib/config/oauth_config.dart` holds the client ID and reads the client secret from the environment via `--dart-define` rather than hardcoding it — pass yours at build/run time as shown above.
