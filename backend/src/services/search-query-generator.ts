import type { FashionVisionResult } from '../api/types.js';
import {
  buildFallbackBrandTypeColor,
  buildFallbackTypeColor,
  buildPrimarySearchQuery,
} from './search-query-assembly.js';

const INVALID_STRINGS = ['null', 'undefined'];

function isValid(s: string | undefined | null): boolean {
  if (s == null || typeof s !== 'string') return false;
  const t = s.trim();
  return t.length > 0 && !INVALID_STRINGS.includes(t.toLowerCase());
}

function hasInvalidPart(s: string): boolean {
  return INVALID_STRINGS.some((bad) => s.toLowerCase().includes(bad));
}

/**
 * Jusqu’à 3 requêtes, entièrement déterministes :
 * 1. Principale (prefix + core + couleur)
 * 2. Fallback : marque/entité + type + couleur
 * 3. Fallback minimal : type + couleur
 */
export function generateSearchQueriesFromVision(
  vision: FashionVisionResult,
  count: number = 3
): string[] {
  const q1 = buildPrimarySearchQuery(vision);
  const q2 = buildFallbackBrandTypeColor(vision);
  const q3 = buildFallbackTypeColor(vision);

  const candidates = [q1, q2, q3];
  const queries: string[] = [];
  const seen = new Set<string>();

  const add = (q: string) => {
    const trimmed = q.trim();
    if (trimmed.length < 2) return;
    if (hasInvalidPart(trimmed)) return;
    const normalized = trimmed.toLowerCase();
    if (seen.has(normalized)) return;
    seen.add(normalized);
    queries.push(trimmed);
  };

  for (const c of candidates) {
    if (isValid(c)) add(c);
    if (queries.length >= Math.min(count, 3)) break;
  }

  const final = queries.slice(0, Math.min(count, 3));

  // eslint-disable-next-line no-console -- traçage
  console.log('[GENERATED_SEARCH_QUERIES_FINAL]', JSON.stringify(final));

  return final;
}
