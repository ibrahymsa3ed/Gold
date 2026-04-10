# What you need to do (before Play Developer account)

This is the **hands-on list only you can do**: passwords, Google consoles, and hosting. The repo already has build scripts; this guide ties them to your actions.

### Where you are now

If you finished **1–4** (keystore + Firebase fingerprints), skipped **5** (AdMob — optional), and did **6** (AAB builds): you are ready for the **pre-launch content** steps below — **7** and **8** — and Play registration (**9**) when you choose.

| Step | Meaning in one line |
|------|---------------------|
| **7** | **Marketing images** for the store page (icon, banner, screenshots, text). Nothing technical in the app — you create files on your computer. |
| **8** | **Privacy policy** = a public web page URL Google requires. You can start from our **template** in the repo, edit it, host it on HTTPS. |
| **9** | Pay for Play Developer account and upload the **AAB** you already built. |

### What the project / assistant can do vs you

| Topic | You | Repo / assistant |
|--------|-----|------------------|
| Keystore, Firebase, AdMob accounts | Yes | Docs + scripts only |
| Store screenshots / graphics | You take or design | Can suggest sizes, emulator tips |
| Privacy policy text | You review & publish | **[docs/PRIVACY_POLICY_TEMPLATE.md](docs/PRIVACY_POLICY_TEMPLATE.md)** draft to customize |
| Play Console forms | You | Checklists in **PLAY_STORE_PREP.md** |

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

## 7. Store listing assets (no Play account needed to *create* them)

Google Play will ask for these **when you create the app listing**. You can prepare them now as files on your computer (Photoshop, Figma, or screenshots only).

**What each one is for:**

| Asset | Size | What it is |
|-------|------|------------|
| **App icon** | **512×512** px PNG | The icon shoppers see on the store. Often the same artwork as the launcher icon, exported at 512×512. |
| **Feature graphic** | **1024×500** px | Wide banner at the top of your store page; usually your logo + tagline on a background. |
| **Phone screenshots** | Min **2** (Play requires at least one phone screenshot in many cases); **4–8** is common | Real captures of your app: Home, My Gold, Settings, etc. Use the same **phone aspect** (e.g. 9:16) for a clean look. |
| **Short description** | Max **80** characters | One line under the app name. |
| **Full description** | Max **4000** characters | Explain features; you can do **English** and **Arabic** if you ship both (or one language first). |

**How to capture screenshots:**

- **Android emulator:** run the app, open each screen, use the emulator’s **Camera** / screenshot tool, or from host:  
  `adb exec-out screencap -p > screenshot_home.png`  
- **Physical phone:** built-in screenshot buttons; copy images to your PC.

**What I (or the repo) cannot do for you:** design the feature graphic or take the photos for you — that’s creative work on your side. The repo can keep **size requirements** accurate in this file.

---

## 8. Privacy policy URL

Play Console requires a **public HTTPS link** to a privacy policy. It must match what your app actually does (sign-in, local data, backups, ads if any, notifications).

**What you do:**

1. Open the draft: **[docs/PRIVACY_POLICY_TEMPLATE.md](docs/PRIVACY_POLICY_TEMPLATE.md)**.
2. Replace **`[YOUR_EMAIL]`**, **`[DATE]`**, and read every section. If you are **not** using AdMob yet, shorten or remove the **“Optional advertising”** part until you enable ads.
3. **Publish** the text as a normal web page with **HTTPS**, for example:
   - **GitHub Pages** from a small repo (free tier, HTTPS included), or  
   - Your own website, or  
   - Any host that gives you a stable `https://…` URL.
4. Save that **URL** — you will paste it into Play **Store listing** and use it to answer **Data safety** consistently.

**Published at:** **https://ibrahymsa3ed.github.io/instagold-privacy/** (GitHub Pages, public repo `instagold-privacy`).

Use this URL in Play Console **Store listing** → **Privacy policy**. If you add AdMob or change data handling later, update both `docs/privacy-policy.md` in this repo and the matching `docs/index.md` in the `instagold-privacy` repo, then push.

**What I can do in the repo:** keep **docs/PRIVACY_POLICY_TEMPLATE.md** and the live policy updated when app behavior changes (new permissions, ads, etc.). **You** must still read it, agree with it, and put it online — Google expects the **developer** to stand behind the policy.

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
