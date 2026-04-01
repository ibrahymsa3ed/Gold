function normalizeKarat(karat) {
  const match = String(karat || "").match(/\d+/);
  return match ? Number(match[0]) : 24;
}

function getBuyPriceForKarat(latestPriceMap, karat) {
  const numeric = normalizeKarat(karat);
  const key = `${numeric}k`;
  const row = latestPriceMap[key];
  return row?.buy_price ?? row?.sell_price ?? 0;
}

function to24kEquivalent(weightG, karat) {
  return (Number(weightG || 0) * normalizeKarat(karat)) / 24;
}

function to21kEquivalent(weightG, karat) {
  return (Number(weightG || 0) * normalizeKarat(karat)) / 21;
}

function buildAssetSummary(assets, latestPriceMap) {
  const summary = {
    current_value: 0,
    purchase_cost: 0,
    profit_loss: 0,
    total_weight_by_karat: {},
    total_weight_24k_equivalent: 0,
    total_weight_21k_equivalent: 0
  };

  assets.forEach((asset) => {
    const marketPrice = getBuyPriceForKarat(latestPriceMap, asset.karat);
    const weight = Number(asset.weight_g || 0);
    const purchasePrice = Number(asset.purchase_price || 0);
    const currentValue = marketPrice * weight;

    summary.current_value += currentValue;
    summary.purchase_cost += purchasePrice;
    summary.total_weight_24k_equivalent += to24kEquivalent(weight, asset.karat);
    summary.total_weight_21k_equivalent += to21kEquivalent(weight, asset.karat);

    const karatKey = String(asset.karat);
    summary.total_weight_by_karat[karatKey] =
      (summary.total_weight_by_karat[karatKey] || 0) + weight;
  });

  summary.profit_loss = summary.current_value - summary.purchase_cost;
  return summary;
}

function calculateGoal({ targetWeightG, karat, savedAmount, latestPriceMap }) {
  const pricePerGram = getBuyPriceForKarat(latestPriceMap, karat);
  const targetPrice = pricePerGram * Number(targetWeightG || 0);
  const saved = Number(savedAmount || 0);
  return {
    target_price: targetPrice,
    saved_amount: saved,
    remaining_amount: Math.max(targetPrice - saved, 0),
    progress_percent: targetPrice > 0 ? Math.min((saved / targetPrice) * 100, 100) : 0
  };
}

function calculateZakat({ totalValue, total24kEquivalentWeight }) {
  const thresholdWeight = 85;
  const isEligible = Number(total24kEquivalentWeight || 0) >= thresholdWeight;
  const zakatDue = isEligible ? Number(totalValue || 0) * 0.025 : 0;
  return {
    threshold_weight_24k: thresholdWeight,
    eligible: isEligible,
    zakat_due: zakatDue
  };
}

module.exports = {
  buildAssetSummary,
  calculateGoal,
  calculateZakat
};
