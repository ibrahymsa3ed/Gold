const axios = require("axios");
const config = require("./config");

async function fetchScraperPrices() {
  const response = await axios.get(config.scraperApiUrl, {
    timeout: 15000,
    headers: {
      "x-api-key": config.scraperApiKey
    }
  });
  return response.data;
}

module.exports = { fetchScraperPrices };
