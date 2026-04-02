import type { FashionVisionResult } from '../api/types.js';

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
 * Génère jusqu'à 4 requêtes propres orientées marketplaces.
 * Priorité : brand+subcategory+color > dominantItem > subcategory+color > subcategory
 */
export function generateSearchQueriesFromVision(
  vision: FashionVisionResult,
  count: number = 4
): string[] {
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

  const category = vision.category ?? '';
  const subcategory = isValid(vision.subcategory)
    ? vision.subcategory!.trim()
    : isValid(category)
      ? category.trim()
      : '';
  const color = isValid(vision.color) ? vision.color!.trim() : '';
  const brand = isValid(vision.probableBrand) ? vision.probableBrand!.trim() : null;
  const dominantItem = isValid(vision.dominantItem)
    ? vision.dominantItem!.trim()
    : null;

  // 1. brand + subcategory + color (si probableBrand existe)
  if (brand && subcategory) {
    add([brand, subcategory, color].filter(Boolean).join(' '));
  }

  // 2. dominantItem (doit être incluse si existe)
  if (dominantItem && dominantItem.length < 60) {
    add(dominantItem);
  }

  // 3. subcategory + color
  if (subcategory && color) {
    add([subcategory, color].join(' '));
  }

  // 4. subcategory seule
  if (subcategory) {
    add(subcategory);
  }

  const final = queries.slice(0, Math.min(count, 4));

  // eslint-disable-next-line no-console -- traçage
  console.log('[GENERATED_SEARCH_QUERIES_FINAL]', JSON.stringify(final));

  return final;
}
