import type { FashionVisionResult } from '../types.js';

const clean = (s: string | undefined) =>
  (s ?? '')
    .replace(/\s+/g, ' ')
    .trim();

/**
 * Requêtes legacy si le modèle ne renvoie pas searchQueries.
 */
function buildLegacyPrimaryQueries(vision: FashionVisionResult): string[] {
  const brand = clean(vision.probableBrand);
  const model = clean(
    vision.fullIdentification ||
      vision.exactModel ||
      vision.inferredModel ||
      vision.dominantItem
  );
  const color = clean(vision.colorway ?? vision.dominantColorPrecise ?? vision.color);
  const cat = clean(
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

/**
 * Au plus 2 requêtes pour le premier chargement :
 * priorité aux searchQueries du modèle vision, sinon fullIdentification + legacy.
 */
export function buildPrimaryQueries(vision: FashionVisionResult): string[] {
  const fromApi = (vision.searchQueries ?? [])
    .map(clean)
    .filter((s) => s.length >= 2);

  if (fromApi.length >= 2) {
    return fromApi.slice(0, 2);
  }

  if (fromApi.length === 1) {
    const first = fromApi[0]!;
    const legacy = buildLegacyPrimaryQueries(vision);
    const fi = clean(vision.fullIdentification);
    const secondFromLegacy = legacy.find(
      (q) => q.toLowerCase() !== first.toLowerCase()
    );
    const secondFromFi =
      fi.length >= 2 && fi.toLowerCase() !== first.toLowerCase() ? fi : undefined;
    const second = secondFromLegacy ?? secondFromFi ?? legacy[0];
    const pair = [first, second].filter((s) => clean(s).length >= 2);
    const uniq = pair.filter(
      (s, i) => pair.findIndex((x) => x.toLowerCase() === s.toLowerCase()) === i
    );
    return uniq.slice(0, 2);
  }

  const fi = clean(vision.fullIdentification);
  if (fi.length >= 3) {
    const legacy = buildLegacyPrimaryQueries(vision);
    const second =
      legacy.find((q) => q.toLowerCase() !== fi.toLowerCase()) ?? legacy[0];
    if (second && second.toLowerCase() !== fi.toLowerCase()) {
      return [fi, second].slice(0, 2);
    }
    if (legacy[0] && legacy[0] !== fi) return [fi, legacy[0]].slice(0, 2);
    return [fi];
  }

  return buildLegacyPrimaryQueries(vision);
}

export function primarySearchQuery(queries: string[], textFallback: string): string {
  if (queries.length > 0) return queries[0];
  return clean(textFallback);
}
