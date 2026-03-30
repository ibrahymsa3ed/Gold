const fs = require("fs");
const path = require("path");
const sqlite3 = require("sqlite3").verbose();
const config = require("./config");

const dbDir = path.dirname(config.dbPath);
if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

const db = new sqlite3.Database(config.dbPath);

const run = (sql, params = []) =>
  new Promise((resolve, reject) => {
    db.run(sql, params, function onRun(error) {
      if (error) return reject(error);
      return resolve(this);
    });
  });

const all = (sql, params = []) =>
  new Promise((resolve, reject) => {
    db.all(sql, params, (error, rows) => {
      if (error) return reject(error);
      return resolve(rows);
    });
  });

async function initDb() {
  await run(`
    CREATE TABLE IF NOT EXISTS ScrapedPrices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      snapshot_id TEXT NOT NULL,
      carat TEXT NOT NULL,
      buy_price REAL,
      sell_price REAL,
      currency TEXT NOT NULL DEFAULT 'EGP',
      updated_at TEXT NOT NULL
    )
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS LogEntries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source TEXT NOT NULL,
      level TEXT NOT NULL,
      action TEXT NOT NULL,
      details TEXT,
      created_at TEXT NOT NULL
    )
  `);
}

module.exports = {
  db,
  run,
  all,
  initDb
};
