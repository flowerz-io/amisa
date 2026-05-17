import type { FashionVisionResult } from '../types.js';

const clean = (s: string | undefined) =>
  (s ?? '')
    .replace(/\s+/g, ' ')
    .trim();

/**
 * Au plus 2 requêtes pour le premier chargement :
 * 1) marque + modèle + catégorie
 * 2) modèle + couleur + catégorie
 */
export function buildPrimaryQueries(vision: FashionVisionResult): string[] {
  const brand = clean(vision.probableBrand);
  const model = clean(vision.inferredModel ?? vision.dominantItem);
  const color =
    clean(vision.dominantColorPrecise ?? vision.color);
  const cat =
    clean(
      vision.itemTypeCanonical ??
        vision.subcategory ??
        vision.category
    );

  const q1Parts = [brand, model, cat].filter((p) => p.length > 0);
  const q2Parts = [model, color, cat].filter((p) => p.length > 0);

  const q1 = q1Parts.join(' ');
  const q2 = q2Parts.join(' ');

  const out: string[] = [];
  if (q1.length >= 3) out.push(q1);
  if (q2.length >= 3 && q2.toLowerCase() !== q1.toLowerCase()) out.push(q2);

  if (out.length === 0 && model.length > 0) out.push(model);
  if (out.length === 0 && cat.length > 0) out.push(cat);

  return out.slice(0, 2);
}

export function primarySearchQuery(queries: string[], textFallback: string): string {
  if (queries.length > 0) return queries[0];
  return clean(textFallback);
}
