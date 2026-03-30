const config = require("./config");
const { admin } = require("./firebase");
const { get, run } = require("./db");
const { logEntry } = require("./logger");

async function upsertUserFromClaims(claims) {
  const existing = await get(`SELECT * FROM Users WHERE firebase_uid = ?`, [claims.uid]);
  if (existing) return existing;

  await run(
    `INSERT INTO Users (firebase_uid, email, password_hash, created_at) VALUES (?, ?, ?, ?)`,
    [claims.uid, claims.email || null, null, new Date().toISOString()]
  );
  return get(`SELECT * FROM Users WHERE firebase_uid = ?`, [claims.uid]);
}

async function requireAuth(req, res, next) {
  try {
    if (config.bypassAuth) {
      const demoUser = { uid: "dev-user", email: "dev@local" };
      const user = await upsertUserFromClaims(demoUser);
      req.auth = { uid: demoUser.uid, email: demoUser.email };
      req.user = user;
      return next();
    }

    const header = req.header("authorization") || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : "";
    if (!token) return res.status(401).json({ message: "Missing bearer token." });

    const decoded = await admin.auth().verifyIdToken(token);
    const user = await upsertUserFromClaims(decoded);
    req.auth = decoded;
    req.user = user;
    return next();
  } catch (error) {
    await logEntry({
      level: "WARN",
      action: "AUTH_FAILURE",
      details: error.message
    });
    return res.status(401).json({ message: "Unauthorized." });
  }
}

module.exports = {
  requireAuth,
  upsertUserFromClaims
};
