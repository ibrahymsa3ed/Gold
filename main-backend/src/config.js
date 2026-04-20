const path = require("path");
const fs = require("fs");

const repoRoot = path.join(__dirname, "..", "..");
const detectedServiceAccount = (() => {
  try {
    const files = fs.readdirSync(repoRoot);
    const match = files.find(
      (name) => name.includes("firebase-adminsdk") && name.endsWith(".json")
    );
    return match ? path.join(repoRoot, match) : "";
  } catch (_) {
    return "";
  }
})();

module.exports = {
  port: Number(process.env.PORT || 4200),
  dbPath:
    process.env.DB_PATH ||
    path.join(__dirname, "..", "data", "main.db"),
  logFile:
    process.env.LOG_FILE ||
    path.join(__dirname, "..", "logs", "app.log"),
  scraperApiUrl:
    process.env.SCRAPER_API_URL || "http://localhost:4100/api/gold-prices",
  scraperApiKey:
    process.env.SCRAPER_API_KEY || "gold_app_secret_ibrahym_2026",
  priceSyncCron: process.env.PRICE_SYNC_CRON || "*/10 * * * *",
  bypassAuth: process.env.BYPASS_AUTH === "true",
  firebaseServiceAccountPath:
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH || detectedServiceAccount,
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || "goldcalculate",
  // FCM fixed-time push summaries — guarded by two layers so nothing fires
  // until both the server flag is on AND the client build number meets the
  // minimum threshold. Defaults below are deliberately closed:
  //   FCM_SUMMARIES_ENABLED=false     -> scheduler never starts
  //   MIN_FCM_CLIENT_BUILD=999999     -> no released build qualifies
  fcmSummariesEnabled: process.env.FCM_SUMMARIES_ENABLED === "true",
  minFcmClientBuild: Number(process.env.MIN_FCM_CLIENT_BUILD || 999999),
  // Cron for the sweep. Every 5 minutes is fine — slots are processed inside
  // a 30-minute window after each fixed Cairo slot (07/11/15/19).
  fcmSweepCron: process.env.FCM_SWEEP_CRON || "*/5 * * * *",
  fcmTimezone: process.env.FCM_TIMEZONE || "Africa/Cairo",
  // Slot window in minutes. A slot is eligible to fire from its start until
  // start + this window, after which it is skipped until next slot.
  fcmSlotWindowMinutes: Number(process.env.FCM_SLOT_WINDOW_MINUTES || 30),
  // If the latest cached price is older than this when a slot is about to
  // fire, the scheduler attempts one re-sync. If still stale, the slot is
  // skipped for that tick and retried on the next 5-min tick (until the slot
  // window expires).
  fcmStaleCacheMinutes: Number(process.env.FCM_STALE_CACHE_MINUTES || 30)
};
