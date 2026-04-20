// 5-minute sweep that delivers fixed-time price summaries to enrolled
// devices.
//
// Slot model
// ----------
// Slots are at 07:00, 11:00, 15:00, 19:00 Africa/Cairo. Luxon handles DST
// transitions automatically. Each slot stays "live" for fcmSlotWindowMinutes
// (default 30). Within that window a slot is delivered exactly once per
// device — gated by `last_sent_slot` on the Devices row.
//
// Stale-cache rule
// ----------------
// If the latest cached price is older than fcmStaleCacheMinutes when the slot
// is live, the scheduler triggers ONE re-sync attempt. If the cache is still
// stale after that, the tick is skipped and the next 5-minute tick will
// retry until the slot window expires. Slots that pass the window without a
// fresh cache are simply skipped — we do not deliver stale prices.
//
// Rollout safety
// --------------
// The whole job is gated on config.fcmSummariesEnabled (master kill switch)
// and a per-row build-number gate (config.minFcmClientBuild) so even with
// the flag on, no device receives a push until its installed app reports a
// build number meeting the threshold.

const schedule = require("node-schedule");
const { DateTime } = require("luxon");
const config = require("./config");
const { logEntry } = require("./logger");
const { syncFromScraper, getLatestCachedPrices } = require("./priceService");
const {
  listDevicesNeedingSlot,
  sendSummary,
  markSlotDelivered
} = require("./notificationsService");

const SLOT_HOURS = [7, 11, 15, 19];

function activeSlot(now) {
  for (const hour of [...SLOT_HOURS].reverse()) {
    const slotStart = now.set({ hour, minute: 0, second: 0, millisecond: 0 });
    if (now < slotStart) continue;
    const minsSinceStart = now.diff(slotStart, "minutes").minutes;
    if (minsSinceStart < config.fcmSlotWindowMinutes) {
      return {
        key: `${slotStart.toISODate()}#${String(hour).padStart(2, "0")}`,
        hour,
        startedAt: slotStart
      };
    }
    return null;
  }
  return null;
}

async function ensureFreshCache() {
  const cached = await getLatestCachedPrices();
  const cutoffMs = config.fcmStaleCacheMinutes * 60 * 1000;
  if (cached) {
    const ageMs = Date.now() - new Date(cached.updated_at).getTime();
    if (ageMs <= cutoffMs) return cached;
  }
  try {
    await syncFromScraper({ force: true });
  } catch (_) {
    // fall through; we'll re-check below.
  }
  const recheck = await getLatestCachedPrices();
  if (!recheck) return null;
  const ageMs = Date.now() - new Date(recheck.updated_at).getTime();
  if (ageMs > cutoffMs) return null;
  return recheck;
}

async function runTick() {
  if (!config.fcmSummariesEnabled) return;

  const now = DateTime.now().setZone(config.fcmTimezone);
  const slot = activeSlot(now);
  if (!slot) return;

  const fresh = await ensureFreshCache();
  if (!fresh) {
    await logEntry({
      level: "WARN",
      action: "FCM_SWEEP_SKIPPED_STALE_CACHE",
      details: `slot=${slot.key}`
    });
    return;
  }

  const devices = await listDevicesNeedingSlot({
    slotKey: slot.key,
    minBuildNumber: config.minFcmClientBuild
  });
  if (!devices.length) return;

  let sent = 0;
  let failed = 0;
  for (const device of devices) {
    // eslint-disable-next-line no-await-in-loop
    const result = await sendSummary({ device, pricesMap: fresh.prices });
    if (result.ok) {
      sent += 1;
      // eslint-disable-next-line no-await-in-loop
      await markSlotDelivered({
        userId: device.user_id,
        deviceId: device.device_id,
        slotKey: slot.key
      });
    } else {
      failed += 1;
    }
  }

  await logEntry({
    action: "FCM_SWEEP_TICK",
    details: `slot=${slot.key} sent=${sent} failed=${failed} eligible=${devices.length}`
  });
}

let started = false;
let job = null;

function startNotificationsScheduler() {
  if (started) return;
  if (!config.fcmSummariesEnabled) {
    // Loud no-op so the boot log makes the gating obvious.
    // eslint-disable-next-line no-console
    console.log(
      "FCM scheduler disabled (FCM_SUMMARIES_ENABLED=false). No pushes will be sent."
    );
    return;
  }
  job = schedule.scheduleJob(config.fcmSweepCron, () => {
    runTick().catch(async (error) => {
      await logEntry({
        level: "ERROR",
        action: "FCM_SWEEP_ERROR",
        details: error.message
      });
    });
  });
  started = true;
  // eslint-disable-next-line no-console
  console.log(
    `FCM scheduler started: cron='${config.fcmSweepCron}' tz='${config.fcmTimezone}' ` +
    `slots=[${SLOT_HOURS.join(",")}] window=${config.fcmSlotWindowMinutes}m ` +
    `min_build=${config.minFcmClientBuild}`
  );
}

function stopNotificationsScheduler() {
  if (job) {
    job.cancel();
    job = null;
  }
  started = false;
}

module.exports = {
  startNotificationsScheduler,
  stopNotificationsScheduler,
  // exported for tests
  _internals: { activeSlot, ensureFreshCache, runTick, SLOT_HOURS }
};
