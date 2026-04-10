# What you need to do (before Play Developer account)

This is the **hands-on list only you can do**: passwords, Google consoles, and hosting. The repo already has build scripts; this guide ties them to your actions.

---

## 1. Create the upload keystore (once — do not lose it)

Run **in a terminal** (macOS/Linux; adjust path if you use Windows — use Git Bash or PowerShell equivalents):

```bash
cd /path/to/Gold/flutter-app/android

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- You will be asked for **keystore password**, **key password** (can match), and your name/org (any label is fine for Play).
- Keep **`upload-keystore.jks`** in a **backup** (USB, cloud you trust, password manager attachment). **Losing it = you cannot ship updates** under the same app id.

**Add to `.gitignore` is already done** for `*.jks` under `flutter-app/android/`. **Never commit** the keystore or `key.properties`.

---

## 2. Create `key.properties`

```bash
cd /path/to/Gold/flutter-app/android
cp key.properties.example key.properties
```

Edit **`key.properties`** with your real passwords and path:

```properties
storePassword=THE_PASSWORD_YOU_CHOSE
keyPassword=THE_KEY_PASSWORD_YOU_CHOSE
keyAlias=upload
storeFile=upload-keystore.jks
```

`storeFile` is relative to the **`android/`** folder (same place as `key.properties`).

---

## 3. Print SHA-1 and SHA-256 for Firebase (Google Sign-In on release builds)

From the **repo root**:

```bash
./scripts/print-release-signing-fingerprints.sh flutter-app/android/upload-keystore.jks upload
```

Enter the keystore password when prompted. In the output, find lines like:

- **`SHA1:`** …
- **`SHA256:`** …

**You will paste these** into Firebase (next step).

---

## 4. Add fingerprints in Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/) → project **goldcalculate** (or your project).
2. **Project settings** (gear) → **Your apps** → Android app **`com.ibrahym.goldfamily`**.
3. Scroll to **SHA certificate fingerprints** → **Add fingerprint**.
4. Add **both** SHA-1 and SHA-256 from step 3.
5. Download the updated **`google-services.json`** if Firebase prompts you, and replace **`flutter-app/android/app/google-services.json`** (if you use that path — keep your project’s actual location in sync).

After this, **rebuild** prod and test **Google Sign-In** on a **release** APK/AAB, not only debug.

---

## 5. (Optional) AdMob — real App ID and banner unit

1. Go to [AdMob](https://admob.google.com/) with your Google account → **Apps** → Add app → match package **`com.ibrahym.goldfamily`**.
2. Note **App ID** (format `ca-app-pub-…~…`) and create a **banner** ad unit; note the **unit id** (`ca-app-pub-…/…`).
3. Put the **App ID** in **`flutter-app/android/app/build.gradle.kts`** inside the **`prod`** flavor’s `manifestPlaceholders["admobAppId"]`.
4. Build prod with your banner unit id, e.g.:

```bash
cd flutter-app
flutter build apk --release --flavor prod \
  --dart-define=INSTAGOLD_FLAVOR=prod \
  --dart-define=ADMOB_BANNER_PROD=ca-app-pub-XXXX/YYYY
```

Use **test ads** while developing; switch to **production** ad units only when you are ready for real users (policy applies).

---

## 6. Verify signed production build locally

From **repo root**:

```bash
./scripts/build-play-aab.sh
```

Confirm the file exists:

`flutter-app/build/app/outputs/bundle/prodRelease/app-prod-release.aab`

Install a prod APK on a phone (from `./scripts/build-and-upload.sh` or manual copy of `app-prod-release.apk`) and test login, home, backup path you care about.

---

## 7. Store listing assets (no account needed to *make* them)

Prepare files locally:

| Asset | Size / notes |
|--------|----------------|
| Icon | 512×512 PNG |
| Feature graphic | 1024×500 |
| Phone screenshots | At least 2; capture from emulator or device |
| Short / full description | Draft in a doc; EN + AR if you ship both |

---

## 8. Privacy policy URL

- Write what data you collect (account, ads, backups, notifications, price sources).
- Host on **HTTPS** (GitHub Pages, your site, etc.).
- You will paste the **URL** into Play Console later and align **Data safety** with the same text.

(A template outline can live in-repo if you add one; you still must review and publish the final page.)

---

## 9. When you buy the Play Developer account

Then: create the app with package **`com.ibrahym.goldfamily`**, upload the **AAB** from step 6, complete **Data safety**, **content rating**, **internal testing** first. See **`PLAY_STORE_PREP.md`** Phase B.

---

## Quick reference — files only you hold

| Secret / asset | Where |
|----------------|--------|
| `upload-keystore.jks` | Your machine + backup |
| `key.properties` | `flutter-app/android/` (gitignored) |
| Keystore passwords | Password manager |
| Firebase / AdMob / Play | Your Google accounts |

If you want the project to **double-check** Gradle signing after you add `key.properties`, run `./scripts/build-play-aab.sh` and fix any errors shown in the terminal.
