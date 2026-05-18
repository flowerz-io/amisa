/**
 * Limites recherche marketplace — alignées sur les variables Railway.
 */

function parseBoundedInt(
  raw: string | undefined,
  fallback: number,
  min: number,
  max: number
): number {
  if (raw === undefined || raw.trim() === '') return fallback;
  const n = Number.parseInt(raw.trim(), 10);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

/** eBay Browse `item_summary/search` — défaut 50, plafond 200 (limite API). */
export function getEbayResultsLimitPerQuery(): number {
  return parseBoundedInt(process.env.EBAY_RESULTS_LIMIT_PER_QUERY, 50, 1, 200);
}

/** Plafond global des annonces renvoyées par `/analyze-search` après fusion. Défaut 100. */
export function getMaxResultsPerSearch(): number {
  return parseBoundedInt(process.env.MAX_RESULTS_PER_SEARCH, 100, 1, 500);
}
