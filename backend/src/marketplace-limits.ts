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

/** Plafond optionnel de résultats Vinted cumulés côté clients (info / doc). */
export const VINTED_MAX_TOTAL_LISTINGS_HINT = clampInt(
  parseInt(process.env.VINTED_MAX_TOTAL_LISTINGS ?? '100', 10),
  1,
  500
);
