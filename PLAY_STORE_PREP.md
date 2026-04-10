# Play Store preparation (before and after developer registration)

**Owner step-by-step (keystore, Firebase, AdMob):** see **[YOUR_ACTIONS_BEFORE_PLAY.md](YOUR_ACTIONS_BEFORE_PLAY.md)**.

You can complete most technical and content work **before** paying the one-time Google Play developer registration fee. This checklist is ordered so nothing blocks you unnecessarily.

---

## Phase A — Do now (no Play Console account required)

### Technical (this repo)

| Task | Notes |
|------|--------|
| **Release keystore** | Create once with `keytool`; store file + passwords in a password manager. Path example: `flutter-app/android/upload-keystore.jks` (gitignored). |
| **`key.properties`** | Copy `flutter-app/android/key.properties.example` → `key.properties`; never commit it. |
| **Signed prod builds** | Run `./scripts/build-play-aab.sh` and confirm `app-prod-release.aab` builds with your upload key (not debug). |
| **Prod APK smoke test** | `./scripts/build-and-upload.sh` or manual prod APK; install on a device, sign in, main flows. |
| **AdMob (optional revenue)** | Use a normal Google account at [admob.google.com](https://admob.google.com): create app, note **App ID** and **banner ad unit ID**. Update `build.gradle.kts` prod `admobAppId` and build with `--dart-define=ADMOB_BANNER_PROD=...`. AdMob does **not** require a paid Play account. |
| **Firebase** | Already using `goldcalculate`; ensure SHA-1/256 for **release** keystore are added in Firebase Console (Android app) so Google Sign-In works on the store build. |

### Store listing assets (can be done in Figma / design tools)

| Asset | Typical spec |
|--------|----------------|
| **App icon** | 512×512 PNG, 32-bit; no transparency for Play. |
| **Feature graphic** | 1024×500 JPG or 24-bit PNG. |
| **Phone screenshots** | At least 2; often 4–8. Min short edge 320px; 16:9 or 9:16 common. |
| **Short description** | ≤80 characters. |
| **Full description** | ≤4000 characters; Arabic + English if you ship both. |

### Legal / policy (host before or right after registration)

| Task | Notes |
|------|--------|
| **Privacy policy URL** | Must be a public HTTPS page describing data you collect (auth, ads, backups, notifications, scraping sources, etc.). GitHub Pages or any host is fine. |
| **Data safety draft** | List: account data, device or advertising IDs if you use ads, backup files, crash data. You will paste this into Play Console later. |

### Accounts to create (free except Play)

- **Google account** — already used for Firebase/AdMob.
- **Play Console** — wait until you are ready to pay the **one-time registration fee** (region-dependent; check [Play Console signup](https://play.google.com/console/signup)).

---

## Phase B — After you register (Play Developer account)

These steps need an active Play Console account:

1. **Create app** — package name **`com.ibrahym.goldfamily`** (must match the published app; do not change casually).
2. **App signing** — Opt in to **Play App Signing**; upload your first **AAB** (`./scripts/build-play-aab.sh` output).
3. **Store listing** — Upload graphics, descriptions, set category, contact email.
4. **Data safety questionnaire** — Align answers with your privacy policy and the app’s real behavior (including AdMob if enabled).
5. **Content rating** — Questionnaire (IARC).
6. **Testing track** — Upload to **internal testing** first; add testers by email; verify install and sign-in.
7. **Production** — Promote when ready.

---

## Quick command reference

```bash
# Dev APK (testing, test ads)
./scripts/build-dev-apk.sh

# Production AAB for Play
./scripts/build-play-aab.sh

# Production APK (sideload / Drive; same signing as AAB when key.properties is set)
./scripts/build-and-upload.sh   # or manual copy from app-prod-release.apk
```

---

## What you cannot do without registration

- Create the Play app ID or upload any build to Play (internal/closed/open/production).
- Complete the live **Data safety** and **store listing** submission for that app (you can still **draft** text and images locally).

---

Keep this file updated if release flow or dependencies change; substantive changes should also be reflected in `README.md` and `ARCHITECTURE.md` per project policy.
