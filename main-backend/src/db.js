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

const get = (sql, params = []) =>
  new Promise((resolve, reject) => {
    db.get(sql, params, (error, row) => {
      if (error) return reject(error);
      return resolve(row || null);
    });
  });

async function tableColumns(tableName) {
  return all(`PRAGMA table_info(${tableName})`);
}

async function ensureColumn(tableName, columnName, definition) {
  const columns = await tableColumns(tableName);
  const hasColumn = columns.some((column) => column.name === columnName);
  if (!hasColumn) {
    await run(`ALTER TABLE ${tableName} ADD COLUMN ${columnName} ${definition}`);
  }
}

async function initDb() {
  await run(`
    CREATE TABLE IF NOT EXISTS Users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      firebase_uid TEXT UNIQUE,
      email TEXT UNIQUE,
      password_hash TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);
  await run(`
    CREATE TABLE IF NOT EXISTS FamilyMembers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      name TEXT NOT NULL,
      relation TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);
  await run(`
    CREATE TABLE IF NOT EXISTS Companies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT DEFAULT 'custom',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);
  await run(`
    CREATE TABLE IF NOT EXISTS Assets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      member_id INTEGER NOT NULL,
      asset_type TEXT NOT NULL,
      karat TEXT NOT NULL,
      company_id INTEGER,
      weight_g REAL NOT NULL,
      purchase_price REAL NOT NULL,
      purchase_date TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);
  await run(`
    CREATE TABLE IF NOT EXISTS Savings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      member_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      currency TEXT DEFAULT 'EGP',
      target_type TEXT DEFAULT NULL,
      target_karat TEXT DEFAULT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);
  await run(`
    CREATE TABLE IF NOT EXISTS PurchaseGoals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      member_id INTEGER NOT NULL,
      company_id INTEGER,
      karat TEXT NOT NULL,
      target_weight_g REAL NOT NULL,
      target_price REAL NOT NULL,
      saved_amount REAL NOT NULL DEFAULT 0,
      remaining_amount REAL NOT NULL DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);
  await run(`
    CREATE TABLE IF NOT EXISTS GoldPriceCache (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source TEXT NOT NULL,
      carat TEXT NOT NULL,
      buy_price REAL,
      sell_price REAL,
      currency TEXT NOT NULL DEFAULT 'EGP',
      fetched_at TEXT NOT NULL
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

  await run(`
    CREATE TABLE IF NOT EXISTS UserSettings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL UNIQUE,
      locale TEXT NOT NULL DEFAULT 'en',
      theme TEXT NOT NULL DEFAULT 'system',
      notification_interval_hours INTEGER NOT NULL DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Devices: one row per (user_id, device_id). fcm_token is intentionally NOT
  // UNIQUE — when a user logs out/in on the same physical device the token
  // can briefly be associated with two user_ids, and when an app reinstall
  // generates a new device_id the old row may still hold the now-rotated
  // token. registerDevice() resolves these collisions atomically.
  // last_sent_slot is the Cairo slot key (e.g. '2026-04-19#11') that was
  // last delivered to this device, used to make the sweep idempotent and to
  // survive token-rotation without re-sending the same slot.
  await run(`
    CREATE TABLE IF NOT EXISTS Devices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      device_id TEXT NOT NULL,
      platform TEXT NOT NULL,
      fcm_token TEXT NOT NULL,
      build_number INTEGER,
      locale TEXT NOT NULL DEFAULT 'en',
      summaries_enabled INTEGER NOT NULL DEFAULT 1,
      last_sent_slot TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE(user_id, device_id)
    )
  `);
  await run(`CREATE INDEX IF NOT EXISTS idx_devices_user ON Devices(user_id)`);
  await run(`CREATE INDEX IF NOT EXISTS idx_devices_enabled ON Devices(summaries_enabled)`);
  await run(`CREATE INDEX IF NOT EXISTS idx_devices_fcm_token ON Devices(fcm_token)`);

  await run(`
    CREATE TABLE IF NOT EXISTS PriceAlerts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      karat TEXT NOT NULL,
      target_price REAL NOT NULL,
      direction TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 1,
      last_triggered_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  `);
  await run(`CREATE INDEX IF NOT EXISTS idx_alerts_user ON PriceAlerts(user_id)`);

  await ensureColumn("Users", "firebase_uid", "TEXT");
  await ensureColumn("FamilyMembers", "user_id", "INTEGER");
  await ensureColumn("Assets", "member_id", "INTEGER");
  await ensureColumn("Savings", "target_type", "TEXT");
  await ensureColumn("Savings", "target_karat", "TEXT");
  await ensureColumn("Assets", "invoice_local_path", "TEXT");

  await run(`CREATE INDEX IF NOT EXISTS idx_members_user ON FamilyMembers (user_id)`);
  await run(`CREATE INDEX IF NOT EXISTS idx_assets_member ON Assets (member_id)`);
  await run(`CREATE INDEX IF NOT EXISTS idx_savings_member ON Savings (member_id)`);
  await run(`CREATE INDEX IF NOT EXISTS idx_goals_member ON PurchaseGoals (member_id)`);

  const defaultCompanies = ["BTC", "L'AZURDE", "SAM", "SHEHATA"];
  for (const company of defaultCompanies) {
    // sqlite has no native upsert-by-constraint without explicit index; keep idempotent by exists check
    // eslint-disable-next-line no-await-in-loop
    const row = await get(`SELECT id FROM Companies WHERE name = ?`, [company]);
    if (!row) {
      // eslint-disable-next-line no-await-in-loop
      await run(`INSERT INTO Companies (name, type) VALUES (?, 'seeded')`, [company]);
    }
  }
}

module.exports = {
  db,
  run,
  all,
  get,
  initDb
};
