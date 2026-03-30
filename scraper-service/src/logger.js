const fs = require("fs");
const path = require("path");
const { run } = require("./db");
const config = require("./config");

const logDir = path.dirname(config.logFile);
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

async function writeLog({ level = "INFO", action, details = "", source = "scraper-service" }) {
  const timestamp = new Date().toISOString();
  const line = `${timestamp} [${level}] ${action} ${details}\n`;
  fs.appendFileSync(config.logFile, line);

  await run(
    `INSERT INTO LogEntries (source, level, action, details, created_at) VALUES (?, ?, ?, ?, ?)`,
    [source, level, action, details, timestamp]
  );
}

module.exports = {
  writeLog
};
