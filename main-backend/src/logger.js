const fs = require("fs");
const path = require("path");
const config = require("./config");
const { run } = require("./db");

const logDir = path.dirname(config.logFile);
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

async function logEntry({ level = "INFO", action, details = "", source = "main-backend" }) {
  const createdAt = new Date().toISOString();
  const line = `${createdAt} [${level}] ${action} ${details}\n`;
  fs.appendFileSync(config.logFile, line);

  await run(
    `INSERT INTO LogEntries (source, level, action, details, created_at) VALUES (?, ?, ?, ?, ?)`,
    [source, level, action, details, createdAt]
  );
}

module.exports = { logEntry };
