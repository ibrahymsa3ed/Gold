const axios = require("axios");
const config = require("./config");

async function fetchScraperPrices({ force = false } = {}) {
  const url = force ? `${config.scraperApiUrl}?force=true` : config.scraperApiUrl;
  const response = await axios.get(url, {
    timeout: 30000,
    headers: {
      "x-api-key": config.scraperApiKey
    }
  });
  return response.data;
}

module.exports = { fetchScraperPrices };
