# InstaGold – Enabling Notifications on Xiaomi / Redmi / MIUI / HyperOS

Xiaomi phones aggressively kill background apps and block notifications by default. Follow **all** steps below to ensure InstaGold notifications work reliably.

## 1. Disable Battery Optimization for InstaGold

1. Open **Settings > Apps > Manage apps**.
2. Find and tap **InstaGold**.
3. Tap **Battery saver** (or **App battery saver**).
4. Select **No restrictions**.

## 2. Enable Autostart

1. Open **Settings > Apps > Manage apps**.
2. Find and tap **InstaGold**.
3. Toggle **Autostart** to ON.

Alternatively:

1. Open **Security** app > **Boost speed** > **Lock** InstaGold.
2. Or go to **Settings > Apps > Autostart** and enable InstaGold.

## 3. Lock the App in Recent Apps

1. Open the recent apps view (swipe up and hold, or tap the square button).
2. Find InstaGold's card.
3. Long-press the card and tap **Lock** (or drag it down to lock).

This prevents MIUI from killing InstaGold when clearing recent apps.

## 4. Allow Notifications

1. Open **Settings > Apps > Manage apps > InstaGold**.
2. Tap **Notifications**.
3. Enable **Show notifications**.
4. Enable **Lock screen notifications** if available.
5. Set notification importance to **Urgent** or **High**.

## 5. Disable MIUI Battery Saver (if enabled)

1. Open **Settings > Battery & performance**.
2. Tap **Battery saver**.
3. Either turn it off, or tap the gear icon and add InstaGold to the exclusion list.

## 6. (HyperOS / MIUI 14+) Background Activity Control

1. Open **Settings > Apps > Manage apps > InstaGold**.
2. Tap **App battery usage** or **Battery usage**.
3. Select **Allow background activity**.

## Verify

After following all steps:

1. Open InstaGold.
2. Go to **Settings** tab.
3. Tap **Send Test Notification**.
4. You should see an InstaGold notification immediately.

If you still don't receive notifications after some time, restart the phone once with these settings applied.

## Why is This Necessary?

Xiaomi's MIUI/HyperOS includes aggressive battery management that kills background processes, including WorkManager tasks that InstaGold uses to check for price changes. This is an OS-level restriction that no app can programmatically bypass — the user must manually whitelist the app.

Other affected manufacturers: Huawei (EMUI), Oppo (ColorOS), Vivo (FunTouch), Samsung (One UI has milder restrictions), OnePlus (OxygenOS).

For a complete list of manufacturer-specific steps, see [dontkillmyapp.com](https://dontkillmyapp.com/).
