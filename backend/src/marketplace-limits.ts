/**
 * Limites scraping / pagination (variables d’environnement optionnelles).
 */

function clampInt(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.min(max, Math.max(min, Math.floor(value)));
}

/** Annonces max par page HTML Vinted (défaut 24, max 96). */
export const VINTED_MAX_PER_PAGE = clampInt(
  parseInt(process.env.VINTED_MAX_PER_PAGE ?? '24', 10),
  1,
  96
);

/** Idem Grailed. */
export const GRAILED_MAX_PER_PAGE = clampInt(
  parseInt(process.env.GRAILED_MAX_PER_PAGE ?? '24', 10),
  1,
  96
);

/** Idem Le Bon Coin. */
export const LEBONCOIN_MAX_PER_PAGE = clampInt(
  parseInt(process.env.LEBONCOIN_MAX_PER_PAGE ?? '40', 10),
  1,
  120
);

/** Réponse initiale rapide (/analyze-search) par provider. */
export const INITIAL_RETURN_PER_PROVIDER = clampInt(
  parseInt(process.env.INITIAL_RETURN_PER_PROVIDER ?? '20', 10),
  1,
  96
);

/** Taille batch pagination (/search-more) par provider. */
export const NEXT_BATCH_PER_PROVIDER = clampInt(
  parseInt(process.env.NEXT_BATCH_PER_PROVIDER ?? '50', 10),
  1,
  120
);

/** Coupe-circuit explicite pagination provider. */
export const MAX_PAGES_PER_PROVIDER = clampInt(
  parseInt(process.env.MAX_PAGES_PER_PROVIDER ?? '40', 10),
  1,
  200
);

/** Plafond optionnel de résultats Vinted cumulés côté clients (info / doc). */
export const VINTED_MAX_TOTAL_LISTINGS_HINT = clampInt(
  parseInt(process.env.VINTED_MAX_TOTAL_LISTINGS ?? '100', 10),
  1,
  500
);
