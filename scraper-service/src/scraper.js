const axios = require("axios");
const cheerio = require("cheerio");
const { run, all } = require("./db");
const { writeLog } = require("./logger");
const config = require("./config");

const CARATS = ["24", "21", "18", "14"];

// In-memory cache for the exchange rate — refreshed at most once per hour
// so the free-tier quota (1,500 req/month) is never exceeded even when the
// gold scraper fires every 10 minutes (~720 exchange-rate calls/month vs
// 4,320 gold-price calls/month).
const _rateCache = { value: null, fetchedAt: 0 };
const _RATE_TTL_MS = 60 * 60 * 1000; // 1 hour

// Fetches live USD/EGP exchange rate (cached, refreshed hourly).
// Primary: ExchangeRate-API.com (set EXCHANGE_RATE_API_KEY in Railway env).
// Fallback: open.er-api.com (no key, daily updates).
async function fetchUsdEgpRate() {
  const now = Date.now();
  if (_rateCache.value !== null && now - _rateCache.fetchedAt < _RATE_TTL_MS) {
    return _rateCache.value;
  }

  let rate = null;

  if (config.exchangeRateApiKey) {
    try {
      const url = `https://v6.exchangerate-api.com/v6/${config.exchangeRateApiKey}/pair/USD/EGP`;
      const res = await axios.get(url, { timeout: 10000 });
      const r = res.data?.conversion_rate;
      if (r && Number.isFinite(r) && r > 0) rate = r;
    } catch (e) {
      await writeLog({ level: "WARN", action: "EXCHANGE_RATE_PRIMARY_FAILED", details: e.message });
    }
  }

  // Fallback — no API key required, updates once per day.
  if (rate === null) {
    try {
      const res = await axios.get("https://open.er-api.com/v6/latest/USD", { timeout: 10000 });
      const r = res.data?.rates?.EGP;
      if (r && Number.isFinite(r) && r > 0) rate = r;
    } catch (e) {
      await writeLog({ level: "WARN", action: "EXCHANGE_RATE_FALLBACK_FAILED", details: e.message });
    }
  }

  if (rate !== null) {
    _rateCache.value = rate;
    _rateCache.fetchedAt = now;
  }
  return rate;
}

function parseNumber(value) {
  if (!value) return null;
  const normalized = String(value).replace(/[^\d.,]/g, "").replace(/,/g, "");
  const parsed = Number(normalized);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
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

  $(".price-item").each((_, el) => {
    const label = $(el).find("span").first().text().trim();
    const numberFonts = $(el).find(".number-font");

    CARATS.forEach((carat) => {
      if (label.includes(`عيار ${carat}`) || label.includes(`${carat}`)) {
        if (output.carats[carat]) return;
        const values = [];
        numberFonts.each((__, numEl) => {
          values.push(parseNumber($(numEl).text()));
        });
        const parentText = $(el).text();
        let sell = values[0];
        let buy = values[1] || values[0];
        if (parentText.indexOf("شراء") < parentText.indexOf("بيع") && values.length >= 2) {
          buy = values[0];
          sell = values[1];
        }
        output.carats[carat] = { buy, sell };
      }
    });

    if (label.includes("الجنيه الذهب")) {
      const val = numberFonts.length > 0 ? parseNumber($(numberFonts[0]).text()) : null;
      if (val) output.goldPoundPrice = val;
    }

    if (label.includes("الأوقية") || label.includes("الأونصة")) {
      const val = numberFonts.length > 0 ? parseNumber($(numberFonts[0]).text()) : null;
      if (val) output.ouncePrice = val;
    }
  });

  if (Object.keys(output.carats).length === 0) {
    const ldJson = $('script[type="application/ld+json"]').html();
    if (ldJson) {
      try {
        const data = JSON.parse(ldJson);
        const props = data.additionalProperty || [];
        props.forEach((prop) => {
          CARATS.forEach((carat) => {
            if (prop.name && prop.name.includes(`عيار ${carat}`) && prop.name.includes("بيع")) {
              output.carats[carat] = output.carats[carat] || {};
              output.carats[carat].sell = parseNumber(prop.value);
              output.carats[carat].buy = output.carats[carat].buy || output.carats[carat].sell;
            }
          });
        });
      } catch (_) { /* ignore parse errors */ }
    }
  }

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

  if (snapshot.usdEgpRate !== null && snapshot.usdEgpRate !== undefined) {
    inserts.push(
      run(
        `INSERT INTO ScrapedPrices (snapshot_id, carat, buy_price, sell_price, currency, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [snapshotId, "usd_egp_rate", snapshot.usdEgpRate, snapshot.usdEgpRate, "EGP", now]
      )
    );
  }

  await Promise.all(inserts);
}

async function scrapeGoldPrices() {
  const startedAt = Date.now();
  try {
    const [response, usdEgpRate] = await Promise.all([
      axios.get(config.sourceUrl, {
        timeout: 20000,
        headers: {
          "User-Agent": "GoldScraper/1.0 (+https://github.com/ibrahymsa3ed/Gold)"
        }
      }),
      fetchUsdEgpRate()
    ]);
    const parsed = parsePrices(response.data);
    parsed.usdEgpRate = usdEgpRate;
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
