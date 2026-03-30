const axios = require("axios");
const cheerio = require("cheerio");
const { run, all } = require("./db");
const { writeLog } = require("./logger");
const config = require("./config");

const CARATS = ["24", "21", "18", "14"];

function parseNumber(value) {
  if (!value) return null;
  const normalized = String(value).replace(/[^\d.,]/g, "").replace(/,/g, "");
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : null;
}

function findPriceNearText($, label) {
  let found = null;
  $("body *").each((_, el) => {
    const text = $(el).text().trim();
    if (!text || !text.includes(label)) return;
    const nextText = $(el).parent().text();
    const match = nextText.match(/(\d[\d,.]+)/);
    if (match) {
      found = parseNumber(match[1]);
      return false;
    }
    return undefined;
  });
  return found;
}

function extractWithRegex(html, pattern) {
  const match = html.match(pattern);
  if (!match || !match[1]) return null;
  return parseNumber(match[1]);
}

function parsePrices(html) {
  const $ = cheerio.load(html);
  const output = {
    carats: {},
    goldPoundPrice: null,
    ouncePrice: null,
    updatedAt: new Date().toISOString(),
    currency: "EGP"
  };

  CARATS.forEach((carat) => {
    const buy = findPriceNearText($, `${carat} عيار`) || extractWithRegex(html, new RegExp(`${carat}\\D{0,30}(\\d[\\d,.]+)`, "i"));
    const sell = findPriceNearText($, `${carat} بيع`) || buy;
    output.carats[carat] = { buy, sell };
  });

  output.goldPoundPrice =
    findPriceNearText($, "الجنيه الذهب") ||
    extractWithRegex(html, /الجنيه الذهب\D{0,40}(\d[\d,.]+)/i);

  output.ouncePrice =
    findPriceNearText($, "الأونصة") ||
    extractWithRegex(html, /(?:الأونصة|ounce)\D{0,40}(\d[\d,.]+)/i);

  return output;
}

async function persistSnapshot(snapshot) {
  const snapshotId = `${Date.now()}`;
  const now = snapshot.updatedAt;
  const inserts = [];

  Object.entries(snapshot.carats).forEach(([carat, prices]) => {
    inserts.push(
      run(
        `INSERT INTO ScrapedPrices (snapshot_id, carat, buy_price, sell_price, currency, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [snapshotId, `${carat}k`, prices.buy, prices.sell, snapshot.currency, now]
      )
    );
  });

  if (snapshot.goldPoundPrice !== null) {
    inserts.push(
      run(
        `INSERT INTO ScrapedPrices (snapshot_id, carat, buy_price, sell_price, currency, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [snapshotId, "gold_pound_8g", snapshot.goldPoundPrice, snapshot.goldPoundPrice, snapshot.currency, now]
      )
    );
  }

  if (snapshot.ouncePrice !== null) {
    inserts.push(
      run(
        `INSERT INTO ScrapedPrices (snapshot_id, carat, buy_price, sell_price, currency, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [snapshotId, "ounce", snapshot.ouncePrice, snapshot.ouncePrice, "USD", now]
      )
    );
  }

  await Promise.all(inserts);
}

async function scrapeGoldPrices() {
  const startedAt = Date.now();
  try {
    const response = await axios.get(config.sourceUrl, {
      timeout: 20000,
      headers: {
        "User-Agent": "GoldScraper/1.0 (+https://github.com/ibrahymsa3ed/Gold)"
      }
    });
    const parsed = parsePrices(response.data);
    await persistSnapshot(parsed);

    await writeLog({
      action: "SCRAPE_SUCCESS",
      details: `duration_ms=${Date.now() - startedAt} source=${config.sourceUrl}`
    });

    return parsed;
  } catch (error) {
    await writeLog({
      level: "ERROR",
      action: "SCRAPE_FAILURE",
      details: error.message
    });
    throw error;
  }
}

async function getLatestPrices() {
  const snapshotRows = await all(
    `SELECT snapshot_id, updated_at
     FROM ScrapedPrices
     ORDER BY id DESC
     LIMIT 1`
  );

  if (!snapshotRows.length) return null;

  const { snapshot_id: snapshotId, updated_at: updatedAt } = snapshotRows[0];
  const rows = await all(
    `SELECT carat, buy_price, sell_price, currency
     FROM ScrapedPrices
     WHERE snapshot_id = ?
     ORDER BY id ASC`,
    [snapshotId]
  );

  const result = {
    updated_at: updatedAt,
    prices: {}
  };

  rows.forEach((row) => {
    result.prices[row.carat] = {
      buy_price: row.buy_price,
      sell_price: row.sell_price,
      currency: row.currency
    };
  });

  return result;
}

module.exports = {
  scrapeGoldPrices,
  getLatestPrices
};
