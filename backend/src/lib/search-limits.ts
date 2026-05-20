/**
 * Limites recherche — alignées sur les variables Railway.
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

/** Plafond global des annonces renvoyées par `/analyze-search` après fusion. Défaut 100. */
export function getMaxResultsPerSearch(): number {
  return parseBoundedInt(process.env.MAX_RESULTS_PER_SEARCH, 100, 1, 500);
}
