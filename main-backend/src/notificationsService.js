// Backend FCM device registry + push delivery for fixed-time price summaries.
//
// Body content rule (matches the locked plan):
//   - Sell prices only for 21K, 24K, and ounce.
//   - English locale renders "21K" / "24K" / "Ounce".
//   - Arabic locale renders "عيار 21" / "عيار 24" / "الأونصه" with Western
//     digits (per product decision — keep numbers in English even in 'ar').
//
// Token de-dup rule:
//   registerDevice() removes any other Devices row holding the same fcm_token
//   inside a single transaction before upserting (user_id, device_id). This
//   handles two real-world cases without ever firing two pushes to the same
//   physical device:
//     1. User A logs out and User B logs in on the same device.
//     2. App reinstall generates a new device_id; OS keeps the same token
//        briefly, so the old row's token gets recycled before pruneInvalidToken
//        catches up.
//   On upsert, last_sent_slot is *preserved* if the row already existed, so a
//   token rotation inside the same active slot does NOT cause a re-send.

const { admin } = require("./firebase");
const { db, run, all, get } = require("./db");
const { logEntry } = require("./logger");
const config = require("./config");

const PRICE_CHANNEL_ID = "price_updates";

// SQLite (node-sqlite3) serializes statements per connection, so wrapping our
// multi-statement work in BEGIN/COMMIT gives us atomicity good enough for our
// single-process backend.
function beginTx() {
  return new Promise((resolve, reject) => {
    db.run("BEGIN IMMEDIATE", (err) => (err ? reject(err) : resolve()));
  });
}
function commitTx() {
  return new Promise((resolve, reject) => {
    db.run("COMMIT", (err) => (err ? reject(err) : resolve()));
  });
}
function rollbackTx() {
  return new Promise((resolve) => {
    db.run("ROLLBACK", () => resolve());
  });
}

function nowIso() {
  return new Date().toISOString();
}

function normalizePlatform(platform) {
  return platform === "ios" ? "ios" : "android";
}

function normalizeLocale(locale) {
  return locale === "ar" ? "ar" : "en";
}

// Augments a device row with `fcm_summaries_active` — true iff this server
// will actually send slot summaries to this device today. The client uses
// this signal to suppress its own local notification firing; that way we
// never double-notify even during partial rollouts.
function withActiveFlag(device) {
  if (!device) return device;
  const buildOk =
    config.fcmSummariesEnabled &&
    Number(device.build_number || 0) >= config.minFcmClientBuild &&
    Number(device.summaries_enabled) === 1;
  return { ...device, fcm_summaries_active: buildOk };
}

async function registerDevice({
  userId,
  deviceId,
  platform,
  fcmToken,
  locale = "en",
  buildNumber = null
}) {
  if (!userId || !deviceId || !platform || !fcmToken) {
    throw new Error("registerDevice: missing required field");
  }
  const plat = normalizePlatform(platform);
  const loc = normalizeLocale(locale);
  const ts = nowIso();

  await beginTx();
  try {
    // 1. Drop any other rows that hold this token (different user OR different
    //    device_id). We never want two devices sharing a token in our table.
    await run(
      `DELETE FROM Devices WHERE fcm_token = ? AND NOT (user_id = ? AND device_id = ?)`,
      [fcmToken, userId, deviceId]
    );
    // 2. Upsert (user_id, device_id) preserving last_sent_slot if present.
    const existing = await get(
      `SELECT id, last_sent_slot FROM Devices WHERE user_id = ? AND device_id = ?`,
      [userId, deviceId]
    );
    if (existing) {
      await run(
        `UPDATE Devices
         SET fcm_token = ?, platform = ?, locale = ?, build_number = ?, updated_at = ?
         WHERE id = ?`,
        [fcmToken, plat, loc, buildNumber, ts, existing.id]
      );
    } else {
      await run(
        `INSERT INTO Devices
         (user_id, device_id, platform, fcm_token, build_number, locale,
          summaries_enabled, last_sent_slot, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, 1, NULL, ?, ?)`,
        [userId, deviceId, plat, fcmToken, buildNumber, loc, ts, ts]
      );
    }
    await commitTx();
  } catch (error) {
    await rollbackTx();
    throw error;
  }

  await logEntry({
    action: "DEVICE_REGISTERED",
    details: `user_id=${userId} device_id=${deviceId} platform=${plat} build=${buildNumber}`
  });
  const row = await get(
    `SELECT * FROM Devices WHERE user_id = ? AND device_id = ?`,
    [userId, deviceId]
  );
  return withActiveFlag(row);
}

async function updateDevice({ userId, deviceId, fields = {} }) {
  const existing = await get(
    `SELECT * FROM Devices WHERE user_id = ? AND device_id = ?`,
    [userId, deviceId]
  );
  if (!existing) return null;

  const next = {
    fcm_token: existing.fcm_token,
    locale: existing.locale,
    summaries_enabled: existing.summaries_enabled,
    build_number: existing.build_number
  };
  if (typeof fields.fcm_token === "string" && fields.fcm_token) {
    next.fcm_token = fields.fcm_token;
  }
  if (typeof fields.locale === "string") {
    next.locale = normalizeLocale(fields.locale);
  }
  if (typeof fields.summaries_enabled === "boolean") {
    next.summaries_enabled = fields.summaries_enabled ? 1 : 0;
  } else if (typeof fields.summaries_enabled === "number") {
    next.summaries_enabled = fields.summaries_enabled ? 1 : 0;
  }
  if (typeof fields.build_number === "number") {
    next.build_number = fields.build_number;
  }

  // If the token changes, repeat the de-dup step to avoid sibling rows
  // colliding on the new token.
  if (next.fcm_token !== existing.fcm_token) {
    await beginTx();
    try {
      await run(
        `DELETE FROM Devices WHERE fcm_token = ? AND NOT (user_id = ? AND device_id = ?)`,
        [next.fcm_token, userId, deviceId]
      );
      await run(
        `UPDATE Devices
         SET fcm_token = ?, locale = ?, summaries_enabled = ?, build_number = ?, updated_at = ?
         WHERE id = ?`,
        [next.fcm_token, next.locale, next.summaries_enabled, next.build_number, nowIso(), existing.id]
      );
      await commitTx();
    } catch (error) {
      await rollbackTx();
      throw error;
    }
  } else {
    await run(
      `UPDATE Devices
       SET locale = ?, summaries_enabled = ?, build_number = ?, updated_at = ?
       WHERE id = ?`,
      [next.locale, next.summaries_enabled, next.build_number, nowIso(), existing.id]
    );
  }

  await logEntry({
    action: "DEVICE_UPDATED",
    details: `user_id=${userId} device_id=${deviceId}`
  });
  const row = await get(`SELECT * FROM Devices WHERE id = ?`, [existing.id]);
  return withActiveFlag(row);
}

async function removeDevice({ userId, deviceId }) {
  const result = await run(
    `DELETE FROM Devices WHERE user_id = ? AND device_id = ?`,
    [userId, deviceId]
  );
  await logEntry({
    action: "DEVICE_REMOVED",
    details: `user_id=${userId} device_id=${deviceId}`
  });
  return result && result.changes > 0;
}

async function pruneInvalidToken(token) {
  if (!token) return;
  await run(`DELETE FROM Devices WHERE fcm_token = ?`, [token]);
  await logEntry({
    level: "WARN",
    action: "DEVICE_TOKEN_PRUNED",
    details: `token_suffix=${token.slice(-8)}`
  });
}

function fmtInt(value) {
  if (value === null || value === undefined) return null;
  const n = Number(value);
  if (!Number.isFinite(n)) return null;
  return Math.round(n).toString();
}

// Builds the localized notification body from a price snapshot.
// Both en + ar use Western digits per product decision.
function buildSummary({ pricesMap, locale = "en" }) {
  const loc = normalizeLocale(locale);
  const sell21 = fmtInt(pricesMap?.["21k"]?.sell_price);
  const sell24 = fmtInt(pricesMap?.["24k"]?.sell_price);
  const sellOunce = fmtInt(pricesMap?.ounce?.sell_price);

  const parts = [];
  if (loc === "ar") {
    if (sell21) parts.push(`عيار 21: ${sell21} جنيه`);
    if (sell24) parts.push(`عيار 24: ${sell24} جنيه`);
    if (sellOunce) parts.push(`الأونصه: $${sellOunce}`);
  } else {
    if (sell21) parts.push(`21K: ${sell21} EGP`);
    if (sell24) parts.push(`24K: ${sell24} EGP`);
    if (sellOunce) parts.push(`Ounce: $${sellOunce}`);
  }

  const title = loc === "ar" ? "أسعار الذهب" : "InstaGold";
  const body = parts.length ? parts.join(" | ") : (
    loc === "ar" ? "تحديث أسعار الذهب الجديد" : "Latest gold prices"
  );
  return { title, body };
}

function buildFcmMessage({ device, title, body }) {
  return {
    token: device.fcm_token,
    notification: { title, body },
    data: {
      kind: "price_summary",
      slot: device.last_sent_slot || ""
    },
    android: {
      priority: "high",
      notification: {
        channelId: PRICE_CHANNEL_ID,
        // The Android client manifest already declares the default icon +
        // accent color via FCM meta-data, but setting them explicitly here
        // makes the payload self-describing and survives manifest drift.
        icon: "ic_stat_notification",
        color: "#D4AF37"
      }
    },
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert"
      },
      payload: {
        aps: {
          alert: { title, body },
          sound: "default"
        }
      }
    }
  };
}

async function sendSummary({ device, pricesMap }) {
  const { title, body } = buildSummary({ pricesMap, locale: device.locale });
  const message = buildFcmMessage({ device, title, body });
  try {
    await admin.messaging().send(message);
    return { ok: true, title, body };
  } catch (error) {
    const code = error && error.code ? error.code : "unknown";
    const invalid =
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/invalid-argument";
    if (invalid) {
      await pruneInvalidToken(device.fcm_token);
    }
    await logEntry({
      level: "WARN",
      action: "FCM_SEND_FAILED",
      details: `device_id=${device.device_id} code=${code}`
    });
    return { ok: false, code };
  }
}

// Marks the slot delivered for this device so the sweep won't re-send it.
async function markSlotDelivered({ deviceId, userId, slotKey }) {
  await run(
    `UPDATE Devices SET last_sent_slot = ?, updated_at = ? WHERE user_id = ? AND device_id = ?`,
    [slotKey, nowIso(), userId, deviceId]
  );
}

async function listDevicesNeedingSlot({ slotKey, minBuildNumber }) {
  return all(
    `SELECT * FROM Devices
     WHERE summaries_enabled = 1
       AND COALESCE(build_number, 0) >= ?
       AND (last_sent_slot IS NULL OR last_sent_slot != ?)`,
    [minBuildNumber, slotKey]
  );
}

async function sendTest({ userId, deviceId, pricesMap }) {
  const device = await get(
    `SELECT * FROM Devices WHERE user_id = ? AND device_id = ?`,
    [userId, deviceId]
  );
  if (!device) return { ok: false, reason: "device_not_found" };
  const result = await sendSummary({ device, pricesMap });
  await logEntry({
    action: "FCM_TEST_SENT",
    details: `user_id=${userId} device_id=${deviceId} ok=${result.ok}`
  });
  return result;
}

module.exports = {
  registerDevice,
  updateDevice,
  removeDevice,
  pruneInvalidToken,
  buildSummary,
  sendSummary,
  sendTest,
  listDevicesNeedingSlot,
  markSlotDelivered
};
