const path = require("path");

module.exports = {
  port: Number(process.env.PORT || 4100),
  sourceUrl:
    process.env.SOURCE_URL || "https://edahabapp.com/",
  apiKey:
    process.env.SCRAPER_API_KEY || "gold_app_secret_ibrahym_2026",
  scheduleCron: process.env.SCRAPE_CRON || "*/10 * * * *",
  dbPath:
    process.env.DB_PATH ||
    path.join(__dirname, "..", "data", "scraper.db"),
  logFile:
    process.env.LOG_FILE ||
    path.join(__dirname, "..", "logs", "scraper.log")
};
