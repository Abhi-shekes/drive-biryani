# Unified Multi-Account Google Drive Search — Plan & Feasibility

## 1. What we're building
A Flutter app where you link **N of your own Google accounts** (personal, work, school, etc.) via OAuth 2.0, type one search query, and see aggregated file results from every linked Drive in one list — with zero recurring cost.

## 2. Feasibility verdict: YES, with one accepted trade-off

| Concern | Verdict | Notes |
|---|---|---|
| Multiple Google accounts via OAuth | ✅ Free | Use `flutter_appauth` (raw OAuth+PKCE), not `google_sign_in` — the latter is built around a single "current user" and fights you when you want several accounts signed in concurrently. |
| Drive API calls | ✅ Free forever | No billing account needed. Quota (new May-2026 model): 1M quota-units/min/project, 325K/min/user, 400M/day — far beyond personal use. |
| Firebase (Auth + Firestore) | ✅ Free forever (Spark plan) | Not a trial — permanently free at this usage level: unlimited Google sign-ins, 50K Firestore reads/day, 20K writes/day, 1GiB storage. |
| Firebase Cloud Functions | ❌ Avoid entirely | Requires the **Blaze** (billing-enabled) plan just to deploy, even if usage stays at $0. Architecture below has **no backend**, so this is a non-issue. |
| Long-lived refresh tokens (no re-auth ever) | ❌ Not free | Requires "Production" publishing status, which for restricted scopes (Drive) needs a **paid CASA Tier 2 audit (~$1,000+/yr)**. Ruled out by your constraint. |
| **Accepted trade-off** | Keep OAuth consent screen in **"Testing" status** (free, no verification). Each linked account's refresh token expires after **7 days**; app detects the failure and prompts a 2-tap reconnect. Up to 100 named test users (yourself + family/friends if you ever share it). |
| Android build/run | ✅ Free forever | Sideload the APK directly. Skip Play Store (needs a one-time $25 fee even for internal testing). |
| iOS build/run | ⚠️ Free but clunky | Personal Apple ID lets you run on your own iPhone, but the build expires every 7 days and needs re-signing from a Mac via Xcode. Real usability = $99/yr Apple Developer Program. **Recommend Android-first.** |

## 3. Architecture (fully client-side — no custom backend, no Cloud Functions)

```
Flutter App
 ├─ Firebase Auth (Spark)         → gates app access, one identity for "you"
 ├─ Cloud Firestore (Spark)       → stores ONLY non-sensitive metadata:
 │                                   which account emails are linked, display name, last synced
 ├─ flutter_secure_storage         → stores each linked account's refresh_token
 │                                   locally, OS keychain/keystore-encrypted (never in Firestore)
 ├─ flutter_appauth                → runs OAuth2 Authorization Code + PKCE flow
 │                                   per Google account, scope = drive.metadata.readonly
 └─ Direct HTTPS calls             → https://oauth2.googleapis.com/token (refresh access token)
                                     https://www.googleapis.com/drive/v3/files (search)
                                     — called straight from the Flutter app, in parallel,
                                     one call per linked account, results merged client-side
```

Why no backend: Android/iOS-type OAuth clients in Google Cloud Console have **no client secret** — refreshing an access token only needs `client_id + refresh_token`, which is safe to do directly from the app. This sidesteps the entire "need a server to hold secrets" problem, which is what keeps Cloud Functions (and its Blaze requirement) out of the picture.

Scope choice: use `drive.metadata.readonly` (file names, ids, mimeType, modified time, link) rather than full `drive.readonly`. Search only needs metadata, and it's the minimal scope for the job — content preview/download can be a later opt-in upgrade requiring `drive.readonly`, added only if you decide you want it.

## 4. Tech stack (all free/open-source)

- Flutter (stable channel)
- `firebase_core`, `firebase_auth`, `cloud_firestore`
- `flutter_appauth` — OAuth2/PKCE, multi-account capable
- `flutter_secure_storage` — encrypted local token storage
- `http` — direct Drive API + token-refresh calls
- No paid packages, no paid SDKs anywhere in this list.

## 5. To-do list (phased)

### Phase 0 — Google Cloud & Firebase setup
- [ ] Create a Google Cloud project (free).
- [ ] Enable **Google Drive API** for the project.
- [ ] Configure OAuth consent screen: **External**, publishing status **Testing**, scopes = `drive.metadata.readonly`, `email`, `profile`.
- [ ] Add yourself (and anyone else who'll use it) as **Test users** (up to 100).
- [ ] Create an OAuth Client ID of type **Android** (SHA-1 fingerprint + package name) — and later **iOS** if you go that route. No client secret needed for these types.
- [ ] Create a Firebase project on the **Spark (free) plan**, link it to the same Google Cloud project.
- [ ] Enable Firebase Auth (Google provider) and Cloud Firestore (Native mode, test/production rules scoped to `request.auth.uid`).

### Phase 1 — Flutter project scaffold
- [ ] `flutter create`, add Android platform (iOS optional/later).
- [ ] Wire up `firebase_core` + `firebase_auth` via FlutterFire CLI.
- [ ] Basic sign-in screen (Firebase Auth, Google provider) — this is "you" opening the app, separate from the per-Drive-account linking below.

### Phase 2 — Multi-account linking flow
- [ ] Integrate `flutter_appauth`.
- [ ] "Add Google Account" button → launches Authorization Code + PKCE flow, `access_type=offline`, `prompt=consent` (forces a refresh_token every time), scope `drive.metadata.readonly`.
- [ ] On success: store `{email, refresh_token}` in `flutter_secure_storage`, and `{email, displayName, linkedAt}` in Firestore under your uid.
- [ ] Support repeating this for a second, third, etc. account (each is an independent flutter_appauth call — no "current session" conflicts since we never touch google_sign_in's native single-account state).

### Phase 3 — Token refresh layer
- [ ] Before each search, for every linked account: POST to `oauth2.googleapis.com/token` with `grant_type=refresh_token` to get a fresh access token.
- [ ] Catch `invalid_grant` (expired/revoked refresh token — expected every 7 days in Testing mode) → mark that account "needs reconnect" instead of crashing the whole search.

### Phase 4 — Search aggregation engine
- [ ] Build Drive `files.list` query string (e.g. `name contains 'query' or fullText contains 'query'`, `trashed=false`).
- [ ] Fire one GET per valid-token account in parallel (`Future.wait`).
- [ ] Merge JSON results, tag each with source account, dedupe if needed, sort (e.g. by `modifiedTime`).

### Phase 5 — Unified search UI
- [ ] Search bar + results list, each row shows file name, icon by mimeType, source-account badge/avatar, modified date.
- [ ] Tap → open `webViewLink` (launches Drive app or browser).
- [ ] Empty/error states, including a visible "reconnect" chip for accounts flagged in Phase 3.

### Phase 6 — Account management screen
- [ ] List linked accounts, manual "Reconnect" button per account, "Remove account" (deletes local token + Firestore entry).

### Phase 7 — Reconnect UX polish
- [ ] Proactive local check: if an account's token is >6 days old, surface a gentle "reconnect soon" nudge before it hard-fails mid-search.

### Phase 8 — Real-world testing
- [ ] Test with at least 2 real Google accounts of your own.
- [ ] Verify the 7-day expiry behavior once (don't need to wait a full week for every test — you can simulate by revoking access manually at myaccount.google.com/permissions).

### Phase 9 — Distribution (personal use)
- [ ] Build release APK, sideload directly to your Android device(s) — no Play Store fee, no cost.
- [ ] (Optional, later) $99/yr Apple Developer Program only if you want real iOS usability beyond 7-day dev builds.

## 6. Known limitations (accepted, not bugs)
- Weekly reconnect per linked account (Testing-mode restricted-scope tokens expire in 7 days).
- Max 100 total users if you ever add named test users beyond yourself.
- `drive.metadata.readonly` gives file metadata + link, not in-app content preview — opening a file hands off to the Drive app/browser.
- No cross-device token sync by design (tokens are local-only for security); only the "which accounts are linked" list syncs via Firestore.

## 7. Optional future upgrades (all cost money — not part of this build)
- CASA Tier 2 verification (~$1,000+/yr) → indefinite refresh tokens, no weekly reconnects.
- Apple Developer Program ($99/yr) → real iOS distribution.
- Google Play Console ($25 one-time) → Play Store listing instead of sideloading.
