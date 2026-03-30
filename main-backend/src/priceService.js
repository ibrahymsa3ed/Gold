const schedule = require("node-schedule");
const config = require("./config");
const { run, all } = require("./db");
const { fetchScraperPrices } = require("./scraperClient");
const { logEntry } = require("./logger");

async function cachePrices(sourcePayload) {
  const fetchedAt = sourcePayload.updated_at || new Date().toISOString();
  const inserts = [];
  Object.entries(sourcePayload.prices).forEach(([carat, values]) => {
    inserts.push(
      run(
        `INSERT INTO GoldPriceCache (source, carat, buy_price, sell_price, currency, fetched_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          "scraper-service",
          carat,
          values.buy_price ?? null,
          values.sell_price ?? null,
          values.currency ?? "EGP",
          fetchedAt
        ]
      )
    );
  });
  await Promise.all(inserts);
}

async function syncFromScraper() {
  try {
    const payload = await fetchScraperPrices();
    await cachePrices(payload);
    await logEntry({
      action: "PRICE_SYNC_SUCCESS",
      details: `fetched_at=${payload.updated_at || "unknown"}`
    });
    return payload;
  } catch (error) {
    await logEntry({
      level: "ERROR",
      action: "PRICE_SYNC_FAILURE",
      details: error.message
    });
    throw error;
  }
}

async function getLatestCachedPrices() {
  const rows = await all(
    `SELECT c1.*
     FROM GoldPriceCache c1
     INNER JOIN (
       SELECT carat, MAX(fetched_at) AS latest_fetched_at
       FROM GoldPriceCache
       GROUP BY carat
     ) c2
       ON c1.carat = c2.carat
      AND c1.fetched_at = c2.latest_fetched_at`
  );

  if (!rows.length) return null;

  const result = {
    updated_at: rows[0].fetched_at,
    prices: {}
  };

  rows.forEach((row) => {
    if (row.fetched_at > result.updated_at) result.updated_at = row.fetched_at;
    result.prices[row.carat] = {
      buy_price: row.buy_price,
      sell_price: row.sell_price,
      currency: row.currency
    };
  });
  return result;
}

function startPriceScheduler() {
  schedule.scheduleJob(config.priceSyncCron, () => {
    syncFromScraper().catch(() => {});
  });
}

module.exports = {
  syncFromScraper,
  getLatestCachedPrices,
  startPriceScheduler
};
