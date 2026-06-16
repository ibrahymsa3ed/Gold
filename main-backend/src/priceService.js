const schedule = require("node-schedule");
const config = require("./config");
const { run, all } = require("./db");
const { fetchScraperPrices } = require("./scraperClient");
const { logEntry } = require("./logger");

async function cachePrices(sourcePayload) {
  const fetchedAt = new Date().toISOString();
  const inserts = [];
  const historyInserts = [];
  Object.entries(sourcePayload.prices).forEach(([carat, values]) => {
    const buy = values.buy_price ?? null;
    const sell = values.sell_price ?? null;
    const currency = values.currency ?? "EGP";
    inserts.push(
      run(
        `INSERT INTO GoldPriceCache (source, carat, buy_price, sell_price, currency, fetched_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
        ["scraper-service", carat, buy, sell, currency, fetchedAt]
      )
    );
    historyInserts.push(
      run(
        `INSERT INTO GoldPriceHistory (carat, buy_price, sell_price, currency, recorded_at)
         VALUES (?, ?, ?, ?, ?)`,
        [carat, buy, sell, currency, fetchedAt]
      )
    );
  });
  await Promise.all(inserts);
  await Promise.all(historyInserts).catch(() => {});
}

async function syncFromScraper({ force = false } = {}) {
  try {
    const payload = await fetchScraperPrices({ force });
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

function startPriceScheduler({ afterSync } = {}) {
  schedule.scheduleJob(config.priceSyncCron, () => {
    syncFromScraper()
      .then((payload) => {
        if (typeof afterSync === "function") {
          return afterSync(payload);
        }
        return null;
      })
      .catch(() => {});
  });
}

async function getPriceHistory(carat, days = 30) {
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
  return all(
    `SELECT carat, buy_price, sell_price, currency, recorded_at
     FROM GoldPriceHistory
     WHERE carat = ? AND recorded_at >= ?
     ORDER BY recorded_at ASC`,
    [carat, since]
  );
}

module.exports = {
  syncFromScraper,
  getLatestCachedPrices,
  startPriceScheduler,
  getPriceHistory
};
