# iG App Icon — Export Bundle

The cleaned iG icon (gold "iG" wordmark with diamond on a black background) at every size you'll need for iOS, Android, and web.

Master source: `source/icon-1024.png` (1024×1024 PNG).

## Folder layout

```
ig_app_icon/
├── source/
│   └── icon-1024.png            ← master, use this to regenerate anything
├── ios/
│   └── AppIcon.appiconset/      ← drop into Xcode's Assets.xcassets
│       ├── Contents.json
│       └── Icon-*.png           ← all 18 sizes (20pt → 1024pt)
├── android/
│   ├── mipmap-mdpi/             ← 48×48
│   ├── mipmap-hdpi/             ← 72×72
│   ├── mipmap-xhdpi/            ← 96×96
│   ├── mipmap-xxhdpi/           ← 144×144
│   ├── mipmap-xxxhdpi/          ← 192×192
│   │   ├── ic_launcher.png      ← square legacy icon
│   │   └── ic_launcher_round.png← round legacy icon (circle-masked)
│   └── play_store_512.png       ← Play Console listing (512×512)
├── web/
│   ├── favicon-16.png           ← browser tab
│   ├── favicon-32.png
│   ├── favicon-48.png
│   ├── favicon-64.png
│   ├── favicon-96.png
│   ├── favicon-128.png
│   ├── favicon-180.png
│   ├── favicon-192.png          ← Android home screen / PWA
│   ├── favicon-256.png
│   ├── favicon-512.png          ← PWA manifest, large icon
│   └── apple-touch-icon.png     ← 180×180, iOS home screen
└── store/
    ├── icon-1024.png            ← App Store listing
    └── icon-512.png
```

## How to install

### iOS (Xcode)
1. Delete the existing `AppIcon.appiconset` from `Assets.xcassets`.
2. Drag `ios/AppIcon.appiconset` into `Assets.xcassets`.
3. In the target's General tab, confirm "App Icons Source" is set to `AppIcon`.

### Android (Android Studio)
1. Copy each `mipmap-*` folder into `app/src/main/res/`, replacing existing files.
2. In `AndroidManifest.xml`, ensure `<application android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher_round" ...>`.
3. If your project currently uses an adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`), delete that file so Android falls back to the new PNGs. (Or generate a new adaptive icon from `source/icon-1024.png` using Android Studio's Image Asset Studio if you want adaptive support.)
4. Upload `play_store_512.png` to the Play Console listing.

### Web
Place files from `web/` at your site root and link them in `<head>`:

```html
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">
<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16.png">
<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
<link rel="icon" type="image/png" sizes="192x192" href="/favicon-192.png">
<link rel="icon" type="image/png" sizes="512x512" href="/favicon-512.png">
```

For a PWA manifest:

```json
{
  "icons": [
    { "src": "/favicon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/favicon-512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```
