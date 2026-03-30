require("dotenv").config();
const express = require("express");
const schedule = require("node-schedule");
const config = require("./config");
const { initDb } = require("./db");
const { writeLog } = require("./logger");
const { scrapeGoldPrices, getLatestPrices } = require("./scraper");

const app = express();
app.use(express.json());

function requireApiKey(req, res, next) {
  const key = req.header("x-api-key");
  if (!key || key !== config.apiKey) {
    writeLog({
      level: "WARN",
      action: "API_UNAUTHORIZED",
      details: `${req.method} ${req.originalUrl}`
    }).catch(() => {});
    return res.status(401).json({ message: "Unauthorized" });
  }
  return next();
}

app.get("/health", (_, res) => {
  res.json({ ok: true, service: "scraper-service" });
});

app.get("/api/gold-prices", requireApiKey, async (req, res) => {
  try {
    const latest = await getLatestPrices();
    await writeLog({
      action: "API_GET_PRICES",
      details: `${req.ip}`
    });

    if (!latest) {
      return res.status(404).json({ message: "No price data yet." });
    }
    return res.json(latest);
  } catch (error) {
    await writeLog({
      level: "ERROR",
      action: "API_GET_PRICES_ERROR",
      details: error.message
    });
    return res.status(500).json({ message: "Failed to fetch prices." });
  }
});

async function bootstrap() {
  await initDb();
  await writeLog({ action: "SERVICE_START", details: `port=${config.port}` });

  schedule.scheduleJob(config.scheduleCron, async () => {
    await scrapeGoldPrices().catch(() => {});
  });

  await scrapeGoldPrices().catch(() => {});

  app.listen(config.port, () => {
    // eslint-disable-next-line no-console
    console.log(`Scraper service running on http://localhost:${config.port}`);
  });
}

bootstrap().catch((error) => {
  // eslint-disable-next-line no-console
  console.error("Failed to bootstrap scraper service:", error);
  process.exit(1);
});
