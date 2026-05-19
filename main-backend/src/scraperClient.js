const axios = require("axios");
const cheerio = require("cheerio");
const config = require("./config");

const CARATS = ["24", "21", "18", "14"];
const SOURCE_URL = config.sourceUrl || "https://edahabapp.com/";

const _rateCache = { value: null, fetchedAt: 0 };
const _RATE_TTL_MS = 60 * 60 * 1000;

function parseNumber(value) {
  if (!value) return null;
  const normalized = String(value).replace(/[^\d.,]/g, "").replace(/,/g, "");
  const parsed = Number(normalized);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

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
    } catch (_) {}
  }

  if (rate === null) {
    try {
      const res = await axios.get("https://open.er-api.com/v6/latest/USD", { timeout: 10000 });
      const r = res.data?.rates?.EGP;
      if (r && Number.isFinite(r) && r > 0) rate = r;
    } catch (_) {}
  }

  if (rate !== null) {
    _rateCache.value = rate;
    _rateCache.fetchedAt = now;
  }
  return rate;
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
      if (label.includes(`عيار ${carat}`) && !output.carats[carat]) {
        const values = [];
        numberFonts.each((__, numEl) => {
          const v = parseNumber($(numEl).text());
          if (v && v > 500) values.push(v);
        });
        if (values.length === 0) return;
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
      if (val && val > 1000) output.goldPoundPrice = val;
    }

    if (label.includes("الأوقية") || label.includes("الأونصة")) {
      const val = numberFonts.length > 0 ? parseNumber($(numberFonts[0]).text()) : null;
      if (val && val > 500 && val < 15000) output.ouncePrice = val;
    }

    if (label.includes("الدولار الأمريكي")) {
      const val = numberFonts.length > 0 ? parseNumber($(numberFonts[0]).text()) : null;
      if (val) output.usdEgpRate = val;
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
              const val = parseNumber(prop.value);
              if (val && val > 500) {
                output.carats[carat].sell = val;
                output.carats[carat].buy = output.carats[carat].buy || val;
              }
            }
          });
        });
      } catch (_) {}
    }
  }

  return output;
}

async function fetchScraperPrices({ force = false } = {}) {
  const [response, usdEgpRate] = await Promise.all([
    axios.get(SOURCE_URL, {
      timeout: 20000,
      headers: { "User-Agent": "InstaGold/2.0" }
    }),
    fetchUsdEgpRate()
  ]);

  const parsed = parsePrices(response.data);
  parsed.usdEgpRate = usdEgpRate;

  const prices = {};
  Object.entries(parsed.carats).forEach(([carat, p]) => {
    prices[`${carat}k`] = {
      buy_price: p.buy,
      sell_price: p.sell,
      currency: "EGP"
    };
  });
  if (parsed.goldPoundPrice) {
    prices["gold_pound_8g"] = {
      buy_price: parsed.goldPoundPrice,
      sell_price: parsed.goldPoundPrice,
      currency: "EGP"
    };
  }
  if (parsed.ouncePrice) {
    prices["ounce"] = {
      buy_price: parsed.ouncePrice,
      sell_price: parsed.ouncePrice,
      currency: "USD"
    };
  }
  if (parsed.usdEgpRate) {
    prices["usd_egp_rate"] = {
      buy_price: parsed.usdEgpRate,
      sell_price: parsed.usdEgpRate,
      currency: "EGP"
    };
  }

  return {
    updated_at: parsed.updatedAt,
    prices
  };
}

module.exports = { fetchScraperPrices };
