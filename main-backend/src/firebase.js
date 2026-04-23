const fs = require("fs");
const admin = require("firebase-admin");
const config = require("./config");

let initialized = false;

function initFirebaseAdmin() {
  if (initialized) return;

  if (config.bypassAuth) {
    initialized = true;
    return;
  }

  // Prefer JSON env var (Railway / CI) over file path.
  const saJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (saJson) {
    const serviceAccount = JSON.parse(saJson);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: config.firebaseProjectId || serviceAccount.project_id,
    });
    initialized = true;
    return;
  }

  if (config.firebaseServiceAccountPath) {
    const raw = fs.readFileSync(config.firebaseServiceAccountPath, "utf-8");
    const serviceAccount = JSON.parse(raw);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: config.firebaseProjectId || serviceAccount.project_id
    });
    initialized = true;
    return;
  }

  admin.initializeApp({
    projectId: config.firebaseProjectId || undefined
  });
  initialized = true;
}

module.exports = {
  admin,
  initFirebaseAdmin
};
