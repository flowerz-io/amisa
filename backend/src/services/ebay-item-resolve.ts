/**
 * Extraction marque / taille depuis la réponse Browse `item_summary/search`.
 *
 * TODO: L’objet ItemSummary peut ne pas inclure `localizedAspects` selon catégories / marketplace.
 * Pour une couverture maximale, envisager un enrichissement via GET /buy/browse/v1/item/{item_id}
 * (getItem), qui expose en général `localizedAspects` complets — coût : 1 appel par annonce.
 */

export type EbayLocalizedAspect = {
  localizedAspectName?: string;
  localizedAspectValue?: string;
  localizedAspectValues?: string[];
};

/** Champs utiles renvoyés par l’API (souvent + champs dynamiques). */
export type EbayBrowseItemLike = {
  itemId?: string;
  title?: string;
  brand?: string;
  shortDescription?: string;
  localizedAspects?: EbayLocalizedAspect[];
  categories?: { categoryId?: string; categoryName?: string }[];
};

function isBrandAspectName(name: string): boolean {
  const n = name.trim().toLowerCase();
  return (
    n === 'brand' ||
    n === 'marque' ||
    n === 'manufacturer' ||
    n === 'fabricant' ||
    n === 'brand name' ||
    n === 'nom de la marque'
  );
}

function isSizeAspectName(name: string): boolean {
  const n = name.trim().toLowerCase();
  return (
    n === 'size' ||
    n === 'taille' ||
    n === 'pointure' ||
    n === 'shoe size' ||
    n === 'taille chaussure' ||
    n === 'taille (eu)' ||
    n === 'taille (us)' ||
    /^size\s*\(men\)$/i.test(name.trim()) ||
    /^size\s*\(women\)$/i.test(name.trim()) ||
    /^size\s*\(unisex\)$/i.test(name.trim())
  );
}

let aspectsDebugLogged = 0;
let resolvedDebugLogged = 0;

export function resetEbayAspectDebugLogCounter(): void {
  aspectsDebugLogged = 0;
  resolvedDebugLogged = 0;
}

function isDebugAspects(): boolean {
  return process.env.EBAY_DEBUG_ASPECTS === '1';
}

export function logEbayAspectsDebugSample(item: EbayBrowseItemLike): void {
  if (!isDebugAspects() || aspectsDebugLogged >= 2) return;
  aspectsDebugLogged += 1;
  const id = item.itemId ?? '(no id)';
  console.log(
    '[EBAY_ASPECTS_DEBUG]',
    JSON.stringify({
      itemId: id,
      brand: item.brand,
      title: item.title?.slice(0, 120),
      shortDescription: item.shortDescription?.slice(0, 200),
      localizedAspects: item.localizedAspects,
      categories: item.categories,
    })
  );
}

function aspectValue(a: EbayLocalizedAspect): string | null {
  const single = a.localizedAspectValue?.trim();
  if (single) return single;
  const arr = a.localizedAspectValues;
  if (arr?.length) {
    const joined = arr.map((x) => String(x).trim()).filter(Boolean);
    if (joined.length) return joined.join(', ');
  }
  return null;
}

function findAspectByNamePredicate(
  aspects: EbayLocalizedAspect[] | undefined,
  predicate: (name: string) => boolean
): string | null {
  if (!aspects?.length) return null;
  for (const a of aspects) {
    const name = (a.localizedAspectName ?? '').trim();
    if (!name) continue;
    if (predicate(name)) {
      const v = aspectValue(a);
      if (v) return v;
    }
  }
  return null;
}

function extractBrandFromTitle(title: string): string | null {
  const t = title.trim();
  if (t.length < 4) return null;
  const m = t.match(/^\s*(.+?)\s*[|]\s+.+/);
  if (m) {
    const cand = m[1].trim();
    if (cand.length >= 2 && cand.length <= 45 && !/^\d+$/.test(cand)) return cand;
  }
  const m2 = t.match(/^\s*(.+?)\s*[–—]\s+.+/);
  if (m2) {
    const cand = m2[1].trim();
    if (cand.length >= 2 && cand.length <= 45 && !/^\d+$/.test(cand)) return cand;
  }
  return null;
}

function extractBrandFromBlurb(text: string | undefined): string | null {
  if (!text) return null;
  const m = text.match(/(?:^|[\n\r])brand\s*[:\s]+\s*([^\n\r]+?)(?:\n|$)/i);
  if (m) {
    const v = m[1].trim().split(/[•|]/)[0]?.trim();
    if (v && v.length >= 2 && v.length <= 60) return v;
  }
  const m2 = text.match(/(?:^|[\n\r])marque\s*[:\s]+\s*([^\n\r]+?)(?:\n|$)/i);
  if (m2) {
    const v = m2[1].trim().split(/[•|]/)[0]?.trim();
    if (v && v.length >= 2 && v.length <= 60) return v;
  }
  return null;
}

export function resolveEbayBrand(item: EbayBrowseItemLike): string | null {
  const direct = typeof item.brand === 'string' ? item.brand.trim() : '';
  if (direct) return direct;

  const fromAspects = findAspectByNamePredicate(item.localizedAspects, isBrandAspectName);
  if (fromAspects) return fromAspects;

  const title = item.title?.trim() ?? '';
  const fromTitle = title ? extractBrandFromTitle(title) : null;
  if (fromTitle) return fromTitle;

  const fromShort = extractBrandFromBlurb(item.shortDescription);
  if (fromShort) return fromShort;

  return null;
}

const ONE_SIZE_RE = /^(one\s*size|one\s*sz|os|o\/s|one\s*sz\.|taille\s*unique|unique)$/i;

function normalizeLetterSizeToken(raw: string): string {
  const lower = raw.trim().toLowerCase();
  const map: Record<string, string> = {
    xs: 'XS',
    s: 'S',
    m: 'M',
    l: 'L',
    xl: 'XL',
    xxl: 'XXL',
    xxxl: 'XXXL',
  };
  if (map[lower]) return map[lower];
  if (/^[smlx]+$/i.test(raw.trim()) && raw.trim().length <= 4) {
    return raw.trim().toUpperCase();
  }
  return raw.trim();
}

/** Normalise affichage taille (y compris One Size → Taille unique). */
export function normalizeEbaySizeDisplay(raw: string): string {
  let s = raw.trim().replace(/\s+/g, ' ');
  if (s.length === 0) return s;
  if (ONE_SIZE_RE.test(s)) return 'Taille unique';
  const lower = s.toLowerCase();
  if (lower === 'os' || lower === 'o/s') return 'Taille unique';

  const letterOnly = /^([smlx]{1,5})$/i;
  const lm = s.match(letterOnly);
  if (lm) return normalizeLetterSizeToken(lm[1]);

  if (/^\d/.test(s) || s.includes('/')) {
    return s;
  }

  if (/^(xs|s|m|l|xl|xxl|xxxl)$/i.test(s)) {
    return normalizeLetterSizeToken(s);
  }

  return s;
}

function extractSizeFromTitle(title: string): string | null {
  const t = title;
  const labeled = t.match(
    /(?:^|[\s,])(?:taille|size|pointure)\s*[:\s]+\s*([^\s,|]+(?:\s*\/\s*[^\s,|]+)?)/i
  );
  if (labeled?.[1]) return labeled[1].trim();

  if (/\b(one\s*size|one\s*sz|os|o\/s)\b/i.test(t)) return 'Taille unique';

  const wordSize = t.match(/\b(XXXL|XXL|XL|XS|S|M|L)\b/i);
  if (wordSize?.[1]) return wordSize[1];

  return null;
}

function extractSizeFromBlurb(text: string | undefined): string | null {
  if (!text) return null;
  const m = text.match(/(?:^|[\n\r])(?:size|taille|pointure)\s*[:\s]+\s*([^\n\r]+?)(?:\n|$)/i);
  if (m?.[1]) {
    const part = m[1].trim().split(/[•|]/)[0]?.trim();
    if (part) return part;
  }
  return null;
}

export function resolveEbaySize(item: EbayBrowseItemLike): string | null {
  const fromAspects = findAspectByNamePredicate(item.localizedAspects, isSizeAspectName);
  if (fromAspects) return normalizeEbaySizeDisplay(fromAspects);

  const fromShort = extractSizeFromBlurb(item.shortDescription);
  if (fromShort) return normalizeEbaySizeDisplay(fromShort);

  const title = item.title?.trim() ?? '';
  if (title) {
    const fromTitle = extractSizeFromTitle(title);
    if (fromTitle) return normalizeEbaySizeDisplay(fromTitle);
  }

  return null;
}

export function logResolvedBrandSizeDebug(
  itemId: string,
  brand: string,
  size: string | null
): void {
  if (!isDebugAspects()) return;
  if (resolvedDebugLogged >= 2) return;
  resolvedDebugLogged += 1;
  console.log('[EBAY_BRAND_RESOLVED]', itemId, brand);
  console.log('[EBAY_SIZE_RESOLVED]', itemId, size ?? '(null)');
}
