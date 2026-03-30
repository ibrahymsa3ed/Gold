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
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || "goldcalculate"
};
