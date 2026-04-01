require("dotenv").config();
const express = require("express");
const cors = require("cors");
const config = require("./config");
const { initDb, all, get, run } = require("./db");
const { logEntry } = require("./logger");
const { syncFromScraper, getLatestCachedPrices, startPriceScheduler } = require("./priceService");
const { buildAssetSummary, calculateGoal, calculateZakat } = require("./calculations");
const { initFirebaseAdmin } = require("./firebase");
const { requireAuth, upsertUserFromClaims } = require("./authMiddleware");

const app = express();
app.use(cors());
app.use(express.json());

async function getMemberForUser(memberId, userId) {
  return get(`SELECT * FROM FamilyMembers WHERE id = ? AND user_id = ?`, [memberId, userId]);
}

app.get("/health", (_, res) => {
  res.json({ ok: true, service: "main-backend" });
});

app.get("/api/prices/current", requireAuth, async (_, res) => {
  try {
    let latest = await getLatestCachedPrices();
    if (latest) {
      const ageMs = Date.now() - new Date(latest.updated_at).getTime();
      if (ageMs > 10 * 60 * 1000) {
        try {
          await syncFromScraper({ force: true });
          latest = await getLatestCachedPrices();
        } catch (_) { /* use stale cache if sync fails */ }
      }
    } else {
      try {
        await syncFromScraper({ force: true });
        latest = await getLatestCachedPrices();
      } catch (_) {}
    }
    await logEntry({ action: "API_GET_CURRENT_PRICES" });
    if (!latest) return res.status(404).json({ message: "No cached prices yet." });
    return res.json(latest);
  } catch (error) {
    await logEntry({ level: "ERROR", action: "API_GET_CURRENT_PRICES_ERROR", details: error.message });
    return res.status(500).json({ message: "Unable to fetch cached prices." });
  }
});

app.post("/api/prices/sync", async (_, res) => {
  try {
    const payload = await syncFromScraper({ force: true });
    return res.json({ message: "Price cache updated.", payload });
  } catch (error) {
    return res.status(500).json({ message: "Sync failed", error: error.message });
  }
});

app.post("/api/auth/session", requireAuth, async (req, res) => {
  return res.json({
    user: req.user,
    auth: {
      uid: req.auth.uid,
      email: req.auth.email || null
    }
  });
});

app.get("/api/me", requireAuth, async (req, res) => {
  const settings = await get(`SELECT * FROM UserSettings WHERE user_id = ?`, [req.user.id]);
  return res.json({ user: req.user, settings });
});

app.put("/api/me/settings", requireAuth, async (req, res) => {
  const locale = req.body.locale || "en";
  const theme = req.body.theme || "system";
  const notificationIntervalHours = Number(req.body.notification_interval_hours || 1);

  const existing = await get(`SELECT id FROM UserSettings WHERE user_id = ?`, [req.user.id]);
  if (!existing) {
    await run(
      `INSERT INTO UserSettings (user_id, locale, theme, notification_interval_hours, updated_at)
       VALUES (?, ?, ?, ?, ?)`,
      [req.user.id, locale, theme, notificationIntervalHours, new Date().toISOString()]
    );
  } else {
    await run(
      `UPDATE UserSettings
       SET locale = ?, theme = ?, notification_interval_hours = ?, updated_at = ?
       WHERE user_id = ?`,
      [locale, theme, notificationIntervalHours, new Date().toISOString(), req.user.id]
    );
  }
  await logEntry({ action: "USER_SETTINGS_UPDATED", details: `user_id=${req.user.id}` });
  const settings = await get(`SELECT * FROM UserSettings WHERE user_id = ?`, [req.user.id]);
  return res.json(settings);
});

app.get("/api/members", requireAuth, async (req, res) => {
  const members = await all(
    `SELECT * FROM FamilyMembers WHERE user_id = ? ORDER BY id DESC`,
    [req.user.id]
  );
  return res.json(members);
});

app.post("/api/members", requireAuth, async (req, res) => {
  const { name, relation = "" } = req.body;
  if (!name) return res.status(400).json({ message: "name is required." });

  await run(
    `INSERT INTO FamilyMembers (user_id, name, relation, created_at) VALUES (?, ?, ?, ?)`,
    [req.user.id, name, relation, new Date().toISOString()]
  );
  await logEntry({ action: "MEMBER_CREATED", details: `user_id=${req.user.id} name=${name}` });
  const members = await all(`SELECT * FROM FamilyMembers WHERE user_id = ? ORDER BY id DESC`, [req.user.id]);
  return res.status(201).json(members[0]);
});

app.put("/api/members/:memberId", requireAuth, async (req, res) => {
  const member = await getMemberForUser(req.params.memberId, req.user.id);
  if (!member) return res.status(404).json({ message: "Member not found." });
  const { name, relation } = req.body;
  if (!name) return res.status(400).json({ message: "name is required." });
  await run(
    `UPDATE FamilyMembers SET name = ?, relation = ? WHERE id = ? AND user_id = ?`,
    [name, relation ?? member.relation, member.id, req.user.id]
  );
  await logEntry({ action: "MEMBER_UPDATED", details: `member_id=${member.id}` });
  const updated = await get(`SELECT * FROM FamilyMembers WHERE id = ?`, [member.id]);
  return res.json(updated);
});

app.delete("/api/members/:memberId", requireAuth, async (req, res) => {
  const member = await getMemberForUser(req.params.memberId, req.user.id);
  if (!member) return res.status(404).json({ message: "Member not found." });
  await run(`DELETE FROM Assets WHERE member_id = ?`, [member.id]);
  await run(`DELETE FROM Savings WHERE member_id = ?`, [member.id]);
  await run(`DELETE FROM PurchaseGoals WHERE member_id = ?`, [member.id]);
  await run(`DELETE FROM FamilyMembers WHERE id = ?`, [member.id]);
  await logEntry({ action: "MEMBER_DELETED", details: `member_id=${member.id}` });
  return res.json({ success: true });
});

app.get("/api/members/:memberId/assets", requireAuth, async (req, res) => {
  const member = await getMemberForUser(req.params.memberId, req.user.id);
  if (!member) return res.status(404).json({ message: "Member not found." });

  const assets = await all(`SELECT * FROM Assets WHERE member_id = ? ORDER BY id DESC`, [member.id]);
  return res.json(assets);
});

app.post("/api/members/:memberId/assets", requireAuth, async (req, res) => {
  const member = await getMemberForUser(req.params.memberId, req.user.id);
  if (!member) return res.status(404).json({ message: "Member not found." });

  const {
    asset_type,
    karat,
    company_id = null,
    weight_g,
    purchase_price,
    purchase_date,
    invoice_local_path = null
  } = req.body;
  if (!asset_type || !karat || !weight_g || !purchase_price || !purchase_date) {
    return res.status(400).json({ message: "Missing required asset fields." });
  }

  await run(
    `INSERT INTO Assets (member_id, asset_type, karat, company_id, weight_g, purchase_price, purchase_date, invoice_local_path, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [member.id, asset_type, karat, company_id, weight_g, purchase_price, purchase_date, invoice_local_path, new Date().toISOString()]
  );
  await logEntry({ action: "ASSET_CREATED", details: `member_id=${member.id}` });
  const assets = await all(`SELECT * FROM Assets WHERE member_id = ? ORDER BY id DESC`, [member.id]);
  return res.status(201).json(assets[0]);
});

app.put("/api/assets/:assetId", requireAuth, async (req, res) => {
  const asset = await get(
    `SELECT a.* FROM Assets a
     INNER JOIN FamilyMembers m ON m.id = a.member_id
     WHERE a.id = ? AND m.user_id = ?`,
    [req.params.assetId, req.user.id]
  );
  if (!asset) return res.status(404).json({ message: "Asset not found." });

  const invPath = Object.prototype.hasOwnProperty.call(req.body, "invoice_local_path")
    ? req.body.invoice_local_path
    : asset.invoice_local_path
  await run(
    `UPDATE Assets
     SET asset_type = ?, karat = ?, company_id = ?, weight_g = ?, purchase_price = ?, purchase_date = ?, invoice_local_path = ?
     WHERE id = ?`,
    [
      req.body.asset_type || asset.asset_type,
      req.body.karat || asset.karat,
      req.body.company_id ?? asset.company_id,
      req.body.weight_g || asset.weight_g,
      req.body.purchase_price || asset.purchase_price,
      req.body.purchase_date || asset.purchase_date,
      invPath,
      asset.id
    ]
  );
  await logEntry({ action: "ASSET_UPDATED", details: `asset_id=${asset.id}` });
  const updated = await get(`SELECT * FROM Assets WHERE id = ?`, [asset.id]);
  return res.json(updated);
});

app.delete("/api/assets/:assetId", requireAuth, async (req, res) => {
  const asset = await get(
    `SELECT a.* FROM Assets a
     INNER JOIN FamilyMembers m ON m.id = a.member_id
     WHERE a.id = ? AND m.user_id = ?`,
    [req.params.assetId, req.user.id]
  );
  if (!asset) return res.status(404).json({ message: "Asset not found." });
  await run(`DELETE FROM Assets WHERE id = ?`, [asset.id]);
  await logEntry({ action: "ASSET_DELETED", details: `asset_id=${asset.id}` });
  return res.json({ success: true });
});

app.get("/api/members/:memberId/assets-summary", requireAuth, async (req, res) => {
  try {
    const { memberId } = req.params;
    const member = await getMemberForUser(memberId, req.user.id);
    if (!member) return res.status(404).json({ message: "Member not found." });
    const assets = await all(`SELECT * FROM Assets WHERE member_id = ?`, [memberId]);
    const prices = await getLatestCachedPrices();
    if (!prices) return res.status(404).json({ message: "No gold prices in cache." });

    const summary = buildAssetSummary(assets, prices.prices);
    await logEntry({ action: "API_MEMBER_ASSETS_SUMMARY", details: `member_id=${memberId}` });
    return res.json({ member_id: Number(memberId), summary, assets_count: assets.length });
  } catch (error) {
    await logEntry({ level: "ERROR", action: "API_MEMBER_ASSETS_SUMMARY_ERROR", details: error.message });
    return res.status(500).json({ message: "Failed to build member summary." });
  }
});

app.post("/api/goals/calculate", requireAuth, async (req, res) => {
  try {
    const { member_id, company_id = null, karat, target_weight_g, saved_amount = 0 } = req.body;
    if (!member_id || !karat || !target_weight_g) {
      return res.status(400).json({ message: "member_id, karat, target_weight_g are required." });
    }
    const member = await getMemberForUser(member_id, req.user.id);
    if (!member) return res.status(404).json({ message: "Member not found." });

    const prices = await getLatestCachedPrices();
    if (!prices) return res.status(404).json({ message: "No gold prices in cache." });

    const goalValues = calculateGoal({
      targetWeightG: target_weight_g,
      karat,
      savedAmount: saved_amount,
      latestPriceMap: prices.prices
    });

    await run(
      `INSERT INTO PurchaseGoals (member_id, company_id, karat, target_weight_g, target_price, saved_amount, remaining_amount)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        member.id,
        company_id,
        karat,
        target_weight_g,
        goalValues.target_price,
        goalValues.saved_amount,
        goalValues.remaining_amount
      ]
    );

    await logEntry({
      action: "GOAL_CREATED",
      details: `member_id=${member.id} karat=${karat} target_weight_g=${target_weight_g}`
    });

    return res.status(201).json(goalValues);
  } catch (error) {
    await logEntry({ level: "ERROR", action: "GOAL_CREATE_ERROR", details: error.message });
    return res.status(500).json({ message: "Failed to calculate/store goal." });
  }
});

app.get("/api/members/:memberId/goals", requireAuth, async (req, res) => {
  const member = await getMemberForUser(req.params.memberId, req.user.id);
  if (!member) return res.status(404).json({ message: "Member not found." });
  const goals = await all(`SELECT * FROM PurchaseGoals WHERE member_id = ? ORDER BY id DESC`, [member.id]);
  return res.json(goals);
});

app.put("/api/goals/:goalId/saved", requireAuth, async (req, res) => {
  const goal = await get(
    `SELECT g.* FROM PurchaseGoals g
     INNER JOIN FamilyMembers m ON m.id = g.member_id
     WHERE g.id = ? AND m.user_id = ?`,
    [req.params.goalId, req.user.id]
  );
  if (!goal) return res.status(404).json({ message: "Goal not found." });

  const prices = await getLatestCachedPrices();
  if (!prices) return res.status(404).json({ message: "No gold prices in cache." });
  const savedAmount = Number(req.body.saved_amount || 0);
  const calc = calculateGoal({
    targetWeightG: goal.target_weight_g,
    karat: goal.karat,
    savedAmount,
    latestPriceMap: prices.prices
  });
  await run(
    `UPDATE PurchaseGoals SET saved_amount = ?, target_price = ?, remaining_amount = ? WHERE id = ?`,
    [calc.saved_amount, calc.target_price, calc.remaining_amount, goal.id]
  );
  await logEntry({ action: "GOAL_SAVED_UPDATED", details: `goal_id=${goal.id}` });
  const updated = await get(`SELECT * FROM PurchaseGoals WHERE id = ?`, [goal.id]);
  return res.json(updated);
});

app.get("/api/members/:memberId/zakat", requireAuth, async (req, res) => {
  try {
    const { memberId } = req.params;
    const member = await getMemberForUser(memberId, req.user.id);
    if (!member) return res.status(404).json({ message: "Member not found." });
    const assets = await all(`SELECT * FROM Assets WHERE member_id = ?`, [memberId]);
    const prices = await getLatestCachedPrices();
    if (!prices) return res.status(404).json({ message: "No gold prices in cache." });

    const summary = buildAssetSummary(assets, prices.prices);
    const zakat = calculateZakat({
      totalValue: summary.current_value,
      total24kEquivalentWeight: summary.total_weight_24k_equivalent
    });

    await logEntry({
      action: "ZAKAT_CALCULATED",
      details: `member_id=${memberId} eligible=${zakat.eligible}`
    });

    return res.json({
      member_id: Number(memberId),
      total_value: summary.current_value,
      total_weight_24k_equivalent: summary.total_weight_24k_equivalent,
      zakat
    });
  } catch (error) {
    await logEntry({ level: "ERROR", action: "ZAKAT_ERROR", details: error.message });
    return res.status(500).json({ message: "Failed to calculate zakat." });
  }
});

app.get("/api/logs", requireAuth, async (_, res) => {
  const rows = await all(`SELECT * FROM LogEntries ORDER BY id DESC LIMIT 200`);
  return res.json(rows);
});

app.get("/api/companies", requireAuth, async (_, res) => {
  const rows = await all(`SELECT * FROM Companies ORDER BY name ASC`);
  return res.json(rows);
});

app.post("/api/companies", requireAuth, async (req, res) => {
  const { name } = req.body;
  if (!name) return res.status(400).json({ message: "name is required." });
  await run(`INSERT INTO Companies (name, type, created_at) VALUES (?, 'custom', ?)`, [
    name,
    new Date().toISOString()
  ]);
  await logEntry({ action: "COMPANY_CREATED", details: `name=${name}` });
  const created = await get(`SELECT * FROM Companies WHERE name = ? ORDER BY id DESC`, [name]);
  return res.status(201).json(created);
});

app.get("/api/members/:memberId/savings", requireAuth, async (req, res) => {
  const member = await getMemberForUser(req.params.memberId, req.user.id);
  if (!member) return res.status(404).json({ message: "Member not found." });
  const rows = await all(`SELECT * FROM Savings WHERE member_id = ? ORDER BY id DESC`, [member.id]);
  const total = rows.reduce((sum, row) => sum + Number(row.amount || 0), 0);
  return res.json({ entries: rows, total_saved: total });
});

app.post("/api/members/:memberId/savings", requireAuth, async (req, res) => {
  const member = await getMemberForUser(req.params.memberId, req.user.id);
  if (!member) return res.status(404).json({ message: "Member not found." });
  const amount = Number(req.body.amount || 0);
  if (!amount) return res.status(400).json({ message: "amount is required." });
  await run(`INSERT INTO Savings (member_id, amount, currency, target_type, target_karat, created_at) VALUES (?, ?, ?, ?, ?, ?)`, [
    member.id,
    amount,
    req.body.currency || "EGP",
    req.body.target_type || null,
    req.body.target_karat || null,
    new Date().toISOString()
  ]);
  await logEntry({ action: "SAVING_ADDED", details: `member_id=${member.id} amount=${amount}` });
  const rows = await all(`SELECT * FROM Savings WHERE member_id = ? ORDER BY id DESC`, [member.id]);
  return res.status(201).json(rows[0]);
});

app.put("/api/savings/:savingId", requireAuth, async (req, res) => {
  const row = await get(
    `SELECT s.id FROM Savings s
     INNER JOIN FamilyMembers m ON m.id = s.member_id
     WHERE s.id = ? AND m.user_id = ?`,
    [req.params.savingId, req.user.id]
  );
  if (!row) return res.status(404).json({ message: "Saving not found." });
  const amount = Number(req.body.amount);
  if (!amount || amount <= 0) return res.status(400).json({ message: "amount is required." });
  await run(`UPDATE Savings SET amount = ? WHERE id = ?`, [amount, req.params.savingId]);
  await logEntry({ action: "SAVING_UPDATED", details: `saving_id=${req.params.savingId}` });
  const updated = await get(`SELECT * FROM Savings WHERE id = ?`, [req.params.savingId]);
  return res.json(updated);
});

app.delete("/api/savings/:savingId", requireAuth, async (req, res) => {
  const row = await get(
    `SELECT s.id FROM Savings s
     INNER JOIN FamilyMembers m ON m.id = s.member_id
     WHERE s.id = ? AND m.user_id = ?`,
    [req.params.savingId, req.user.id]
  );
  if (!row) return res.status(404).json({ message: "Saving not found." });
  await run(`DELETE FROM Savings WHERE id = ?`, [req.params.savingId]);
  await logEntry({ action: "SAVING_DELETED", details: `saving_id=${req.params.savingId}` });
  return res.json({ success: true });
});

async function bootstrap() {
  await initDb();
  initFirebaseAdmin();
  if (config.bypassAuth) {
    await upsertUserFromClaims({ uid: "dev-user", email: "dev@local" });
  }
  await logEntry({ action: "SERVICE_START", details: `port=${config.port}` });
  startPriceScheduler();
  await syncFromScraper().catch(() => {});

  app.listen(config.port, () => {
    // eslint-disable-next-line no-console
    console.log(`Main backend running on http://localhost:${config.port}`);
  });
}

bootstrap().catch((error) => {
  // eslint-disable-next-line no-console
  console.error(error);
  process.exit(1);
});
