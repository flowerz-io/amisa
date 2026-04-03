/**
 * Assemblage déterministe des search queries à partir de FashionVisionResult.
 * Pas de texte marketing : uniquement segments structurés, dédoublonnage, ordre fixe.
 */

import type { FashionVisionResult } from '../api/types.js';

const INVALID = new Set(['null', 'undefined', '']);

function clean(s: string | undefined | null): string | null {
  if (s == null || typeof s !== 'string') return null;
  const t = s.trim();
  if (t.length === 0 || INVALID.has(t.toLowerCase())) return null;
  if (t.toLowerCase().includes('null')) return null;
  return t;
}

/** Couleur unique pour la query : précise d’abord, sinon legacy color */
export function pickColor(v: FashionVisionResult): string | null {
  return clean(v.dominantColorPrecise) ?? clean(v.color);
}

/**
 * Le segment « type » est-il déjà couvert par le modèle / sous-catégorie (évite jacket+jacket).
 */
/** Si le modèle commence par la marque déjà en prefix, retirer la marque du segment modèle. */
export function stripLeadingBrand(model: string, brand: string | null): string {
  if (!brand) return model;
  const b = brand.trim();
  const m = model.trim();
  if (!b || !m) return model;
  const bl = b.toLowerCase();
  const ml = m.toLowerCase();
  if (ml === bl) return m;
  if (ml.startsWith(bl + ' ')) return m.slice(b.length).trim();
  return model;
}

export function typeRedundantWithSegment(segment: string, itemType: string): boolean {
  const s = segment.toLowerCase().trim();
  const t = itemType.toLowerCase().trim();
  if (!s || !t || t.length < 2) return false;
  const words = s.split(/\s+/).filter(Boolean);
  if (words.some((w) => w === t)) return true;
  if (s.includes(t) && (t.length >= 4 || words.length === 1)) return true;
  return false;
}

/**
 * Supprime les segments identiques en casse, en conservant l’ordre et la première forme.
 */
export function dedupeSegmentsCaseInsensitive(segments: string[]): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const seg of segments) {
    const t = seg.trim();
    if (!t) continue;
    const key = t.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(t);
  }
  return out;
}

/**
 * Concatène prefix + cœur + couleur avec dédoublonnage insensible à la casse.
 */
export function joinQueryParts(parts: (string | null | undefined)[]): string {
  const flat = parts.flatMap((p) => {
    const c = clean(p);
    return c ? [c] : [];
  });
  return dedupeSegmentsCaseInsensitive(flat).join(' ');
}

/** Prefix : marque, entité sport/franchise, marquage secondaire (collab, logo texte). */
export function buildPrefixSegments(v: FashionVisionResult): string[] {
  return dedupeSegmentsCaseInsensitive(
    [clean(v.probableBrand), clean(v.inferredEntity), clean(v.secondaryMarking)].flatMap((x) =>
      x ? [x] : []
    )
  );
}

/**
 * Cœur produit : modèle si sûr, sinon sous-catégorie, sinon catégorie, sinon fallback.
 * Peut ajouter itemTypeCanonical si nécessaire et non redondant.
 */
export function buildCoreSegments(v: FashionVisionResult): string[] {
  const brand = clean(v.probableBrand);
  const rawModel = clean(v.inferredModel);
  let model: string | null = null;
  if (rawModel) {
    const stripped = stripLeadingBrand(rawModel, brand);
    model = stripped.length > 0 ? stripped : null;
  }
  const sub = clean(v.subcategory);
  const cat = clean(v.category);
  const itemType = clean(v.itemTypeCanonical);

  if (model) {
    const parts = [model];
    if (itemType && !typeRedundantWithSegment(model, itemType)) {
      parts.push(itemType);
    }
    return dedupeSegmentsCaseInsensitive(parts);
  }

  if (sub) {
    const parts = [sub];
    if (itemType && !typeRedundantWithSegment(sub, itemType)) {
      parts.push(itemType);
    }
    return dedupeSegmentsCaseInsensitive(parts);
  }

  if (cat) {
    const parts = [cat];
    if (itemType && !typeRedundantWithSegment(cat, itemType)) {
      parts.push(itemType);
    }
    return dedupeSegmentsCaseInsensitive(parts);
  }

  if (itemType) {
    return [itemType];
  }

  return ['fashion item'];
}

/** Query principale : prefix + core + couleur. */
export function buildPrimarySearchQuery(v: FashionVisionResult): string {
  const prefix = buildPrefixSegments(v);
  const core = buildCoreSegments(v);
  const color = pickColor(v);

  const segments = dedupeSegmentsCaseInsensitive([...prefix, ...core, ...(color ? [color] : [])]);
  return segments.join(' ').trim();
}

/** Fallback 2 : marque/entité (+ sous-marquage optionnel léger) + type + couleur — version plus courte. */
export function buildFallbackBrandTypeColor(v: FashionVisionResult): string {
  const prefix = dedupeSegmentsCaseInsensitive(
    [clean(v.probableBrand), clean(v.inferredEntity)].flatMap((x) => (x ? [x] : []))
  );
  const typePart =
    clean(v.subcategory) ?? clean(v.category) ?? clean(v.itemTypeCanonical) ?? 'fashion item';
  const color = pickColor(v);
  return joinQueryParts([...prefix, typePart, color]);
}

/** Fallback 3 : sous-catégorie ou catégorie + couleur. */
export function buildFallbackTypeColor(v: FashionVisionResult): string {
  const typePart =
    clean(v.subcategory) ?? clean(v.category) ?? clean(v.itemTypeCanonical) ?? 'fashion item';
  const color = pickColor(v);
  return joinQueryParts([typePart, color]);
}
