/**
 * Extraction / normalisation taille Vinted (champs API, titre, page détail).
 */

export type VintedSizeSource = 'list' | 'detail' | 'regex';

export interface VintedResolvedSize {
  size: string | null;
  source: VintedSizeSource | null;
}

const ONE_SIZE_RE =
  /\b(one\s*size|taille\s*unique|unique|tu|os)\b/i;

/** Vêtements : XS … XXXL */
const CLOTHING_RE = /\b(XXXL|XXL|XL|L|M|S|XS|XXS)\b/;

const SHOE_FRACTION_RE =
  /\b(3[5-9]|4[0-8])\s*([12])\s*\/\s*([23])\b/;
const SHOE_DECIMAL_RE = /\b(3[5-9]|4[0-8])[.,]([05])\b/;
const SHOE_T_RE = /\bT\s*(3[5-9]|4[0-8])(?:[.,][05])?\b/i;
const TAILLE_NUM_RE =
  /\btaille\s*(3[5-9]|4[0-8])(?:\s*[12]\s*\/\s*[23])?\b/i;
const SIZE_KW_RE =
  /\b(?:size|pointure|eu|uk|us)\s*(3[5-9]|4[0-8])(?:\s*[12]\s*\/\s*[23]|[.,][05])?\b/i;
const FEMME_HOMME_RE =
  /\b(3[5-9]|4[0-8])\s*(?:femme|homme|women|men|w|m)\b/i;
const FEMME_HOMME_SUFFIX_RE =
  /\b(?:femme|homme|women|men)\s*(3[5-9]|4[0-8])\b/i;

/** Évite faux positifs type « Spezial 36 », prix, années. */
const MODEL_NOISE_RE =
  /\b(spezial|samba|gazelle|campus|forum|superstar|stan\s*smith|air\s*max|dunk|jordan|yeezy|550|2002|990|574|9060)\s*\d{2}\b/i;
const YEAR_RE = /\b(19|20)\d{2}\b/;
const PRICE_LIKE_RE = /\b\d+[.,]\d{2}\s*€/;

/** Normalise un libellé brut en taille affichable ou `null`. */
export function normalizeVintedSize(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;

  if (ONE_SIZE_RE.test(trimmed)) return 'OS';

  const upper = trimmed.toUpperCase();
  if (upper === 'TU') return 'OS';
  if (upper === 'OS') return 'OS';
  if (upper === 'NS') return null;

  const frac = trimmed.match(SHOE_FRACTION_RE);
  if (frac) return `${frac[1]} ${frac[2]}/${frac[3]}`;

  const dec = trimmed.match(SHOE_DECIMAL_RE);
  if (dec) return `${dec[1]}.${dec[2]}`;

  const clothing = trimmed.match(CLOTHING_RE);
  if (clothing) return clothing[1].toUpperCase();

  const shoeOnly = trimmed.match(/^(3[5-9]|4[0-8])$/);
  if (shoeOnly) return shoeOnly[1];

  const shoeWithUnit = trimmed.match(/^(3[5-9]|4[0-8])\s*(?:EU|eu|cm)?$/);
  if (shoeWithUnit) return shoeWithUnit[1];

  return null;
}

export function normalizeVintedSizeLabel(raw: string): string {
  return normalizeVintedSize(raw) ?? raw.trim();
}

function readNestedLabel(value: unknown): string | undefined {
  if (typeof value === 'string') {
    const t = value.trim();
    return t || undefined;
  }
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    const o = value as Record<string, unknown>;
    for (const key of ['title', 'name', 'label', 'size', 'value']) {
      const v = o[key];
      if (typeof v === 'string' && v.trim()) return v.trim();
    }
  }
  return undefined;
}

function scanAttributeArrays(row: Record<string, unknown>): string | undefined {
  for (const key of [
    'attributes',
    'item_attributes',
    'details',
    'plugins',
    'item_box',
  ]) {
    const arr = row[key];
    if (!Array.isArray(arr)) continue;
    for (const entry of arr) {
      if (!entry || typeof entry !== 'object') continue;
      const a = entry as Record<string, unknown>;
      const code = String(a.code ?? a.type ?? a.key ?? a.title ?? a.name ?? '')
        .toLowerCase()
        .trim();
      if (
        code.includes('size') ||
        code.includes('taille') ||
        code === 's'
      ) {
        const val =
          readNestedLabel(a.value) ??
          readNestedLabel(a.title) ??
          readNestedLabel(a.name);
        if (val) return val;
      }
      const title = typeof a.title === 'string' ? a.title.toLowerCase() : '';
      if (title.includes('taille') || title.includes('size')) {
        const val =
          readNestedLabel(a.value) ??
          (typeof a.description === 'string' ? a.description.trim() : undefined);
        if (val) return val;
      }
    }
  }
  return undefined;
}

function readTextFields(row: Record<string, unknown>): string | undefined {
  for (const key of [
    'subtitle',
    'description',
    'size_title',
    'size_label',
    'sizeLabel',
    'item_size_title',
    'itemSize',
    'taille',
  ]) {
    const v = row[key];
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  for (const key of ['size', 'item_size']) {
    const nested = readNestedLabel(row[key]);
    if (nested) return nested;
  }
  return scanAttributeArrays(row);
}

/** Lit la taille depuis un item brut `catalog/items` ou détail API. */
export function readSizeFromVintedRow(
  row: Record<string, unknown>
): string | null {
  const raw = readTextFields(row);
  if (!raw) return null;
  return normalizeVintedSize(raw);
}

function titleLooksNoisy(title: string): boolean {
  return (
    MODEL_NOISE_RE.test(title) ||
    PRICE_LIKE_RE.test(title) ||
    YEAR_RE.test(title)
  );
}

/** Fallback : extrait une taille probable depuis le titre (regex prudentes). */
export function extractSizeFromTitle(title: string): string | null {
  const t = title.trim();
  if (!t) return null;

  if (ONE_SIZE_RE.test(t)) return 'OS';

  const frac = t.match(SHOE_FRACTION_RE);
  if (frac) return `${frac[1]} ${frac[2]}/${frac[3]}`;

  const dec = t.match(SHOE_DECIMAL_RE);
  if (dec) return `${dec[1]}.${dec[2]}`;

  const tShoe = t.match(SHOE_T_RE);
  if (tShoe) return tShoe[1];

  const taille = t.match(TAILLE_NUM_RE);
  if (taille) {
    const fracIn = t.match(
      new RegExp(`taille\\s*${taille[1]}\\s*([12])\\s*\\/\\s*([23])`, 'i')
    );
    if (fracIn) return `${taille[1]} ${fracIn[1]}/${fracIn[2]}`;
    return taille[1];
  }

  const sizeKw = t.match(SIZE_KW_RE);
  if (sizeKw) {
    const fracIn = t.match(
      new RegExp(
        `(?:size|pointure|eu|uk|us)\\s*${sizeKw[1]}\\s*([12])\\s*\\/\\s*([23])`,
        'i'
      )
    );
    if (fracIn) return `${sizeKw[1]} ${fracIn[1]}/${fracIn[2]}`;
    const decIn = t.match(
      new RegExp(`(?:size|pointure|eu|uk|us)\\s*${sizeKw[1]}[.,]([05])`, 'i')
    );
    if (decIn) return `${sizeKw[1]}.${decIn[1]}`;
    return sizeKw[1];
  }

  const femme = t.match(FEMME_HOMME_RE);
  if (femme) return femme[1];

  const femmeSuffix = t.match(FEMME_HOMME_SUFFIX_RE);
  if (femmeSuffix) return femmeSuffix[1];

  const clothing = t.match(CLOTHING_RE);
  if (clothing) return clothing[1].toUpperCase();

  if (!titleLooksNoisy(t)) {
    const contextual = t.match(
      /\b(?:taille|size|pointure)\s*(XXXL|XXL|XL|L|M|S|XS|XXS)\b/i
    );
    if (contextual) return contextual[1].toUpperCase();
  }

  return null;
}

/** Résout la taille depuis tous les champs d'un item brut + titre. */
export function normalizeVintedSizeFromItem(
  rawItem: Record<string, unknown>,
  title: string
): VintedResolvedSize {
  const fromList = readSizeFromVintedRow(rawItem);
  if (fromList) {
    return { size: fromList, source: 'list' };
  }

  const fromTitle = extractSizeFromTitle(title);
  if (fromTitle) {
    return { size: fromTitle, source: 'regex' };
  }

  return { size: null, source: null };
}

export function resolveVintedListingSize(
  row: Record<string, unknown>,
  title: string
): string | undefined {
  const { size } = normalizeVintedSizeFromItem(row, title);
  return size ?? undefined;
}

export function logVintedListingRaw(
  row: Record<string, unknown>,
  title: string,
  size: string | null | undefined
): void {
  console.log('[VINTED_LISTING_RAW]', {
    title,
    size: size ?? null,
    raw: row,
  });
}

export function logVintedSize(
  title: string,
  source: VintedSizeSource,
  size: string | null
): void {
  console.log('[VINTED_SIZE]', {
    title: title.slice(0, 80),
    source,
    size,
  });
}
