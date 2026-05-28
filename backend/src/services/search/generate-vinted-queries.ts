export interface VintedQueryInput {
  brand: string;
  model: string;
  exactColorway?: string;
  dominantColor?: string;
  secondaryColor?: string;
}

export interface VintedQueryOutput {
  queries: string[];
}

const FORBIDDEN_CHARS = /[()/\\]/g;

/** Mots matière souvent retirés quand une collab rend le modèle discriminant. */
const MATERIAL_TOKENS = new Set([
  'nylon',
  'leather',
  'cuir',
  'suede',
  'canvas',
  'mesh',
  'primeknit',
  'corduroy',
  'denim',
  'velours',
]);

const COLLAB_MARKERS = [
  'wales bonner',
  'bad bunny',
  'travis scott',
  'off-white',
  'off white',
  'yeezy',
  'palace',
  'supreme',
  'stussy',
  'kith',
  'bape',
  'comme des garcons',
  'sacai',
  'union',
  'jordan x',
  'nike x',
  'adidas x',
];

function cleanToken(value: string): string {
  return value
    .replace(FORBIDDEN_CHARS, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** Retire le colorway du modèle s’il y a été recopié. */
function stripColorwayFromModel(model: string, exactColorway: string): string {
  let m = model;
  if (!exactColorway) return cleanToken(m);
  for (const word of exactColorway.split(/\s+/)) {
    if (word.length < 3) continue;
    m = m.replace(new RegExp(`\\b${escapeRegExp(word)}\\b`, 'gi'), ' ');
  }
  return cleanToken(m);
}

function modelHasCollaboration(model: string): boolean {
  const lower = model.toLowerCase();
  return COLLAB_MARKERS.some((m) => lower.includes(m));
}

function isGenericModel(model: string): boolean {
  const tokens = cleanToken(model).split(/\s+/).filter(Boolean);
  if (tokens.length === 0) return true;
  if (modelHasCollaboration(model)) return false;
  return tokens.length <= 2;
}

/** Modèle raccourci pour Vinted (ex. Samba Nylon Wales Bonner → Samba Wales Bonner). */
function simplifyModel(model: string): string {
  let tokens = cleanToken(model).split(/\s+/).filter(Boolean);
  if (tokens.length <= 2) return tokens.join(' ');

  if (modelHasCollaboration(model)) {
    tokens = tokens.filter((t) => !MATERIAL_TOKENS.has(t.toLowerCase()));
  } else if (tokens.length > 3) {
    tokens = tokens.slice(0, 3);
  }

  return tokens.join(' ').trim();
}

/** Supprime les répétitions consécutives de la marque (ex. Adidas Adidas Samba). */
export function removeDuplicateBrand(query: string, brand: string): string {
  const b = cleanToken(brand);
  if (!b) return cleanToken(query);

  const parts = cleanToken(query).split(/\s+/);
  const brandLower = b.toLowerCase();
  let brandSeen = false;
  const out: string[] = [];

  for (const part of parts) {
    if (part.toLowerCase() === brandLower) {
      if (brandSeen) continue;
      brandSeen = true;
    }
    out.push(part);
  }

  return out.join(' ').trim();
}

function sanitizeQuery(query: string, brand: string): string {
  let q = cleanToken(query);
  if (!q) return '';

  const b = cleanToken(brand);
  if (b) {
    const dup = new RegExp(
      `(\\b${escapeRegExp(b)}\\b)(?:\\s+\\1)+`,
      'gi'
    );
    q = q.replace(dup, b);
  }

  q = removeDuplicateBrand(q, brand);

  if (b && q.toLowerCase().startsWith(`${b.toLowerCase()} ${b.toLowerCase()} `)) {
    q = q.slice(b.length + 1).trim();
    q = `${b} ${q}`.trim();
  }

  return q;
}

function dedupeQueries(queries: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const q of queries) {
    const key = q.toLowerCase();
    if (key.length < 2 || seen.has(key)) continue;
    seen.add(key);
    out.push(q);
  }
  return out;
}

/**
 * Génère jusqu'à 3 requêtes Vinted :
 * 1) marque + modèle exact (sans colorway long)
 * 2) marque + modèle simplifié
 * 3) modèle simplifié sans marque
 * Couleur uniquement si modèle générique (pas de collab discriminante).
 */
export function generateVintedQueries(input: VintedQueryInput): VintedQueryOutput {
  const brand = cleanToken(input.brand);
  const exactColorway = cleanToken(input.exactColorway ?? '');
  const dominantColor = cleanToken(input.dominantColor ?? '');
  const modelExact = stripColorwayFromModel(cleanToken(input.model), exactColorway);

  if (!modelExact) {
    return { queries: [] };
  }

  const modelSimple = simplifyModel(modelExact);
  const generic = isGenericModel(modelExact);

  const candidates: string[] = [];

  const q1 = sanitizeQuery([brand, modelExact].filter(Boolean).join(' '), brand);
  const q2 = sanitizeQuery([brand, modelSimple].filter(Boolean).join(' '), brand);
  const q3 = sanitizeQuery(modelSimple, brand);

  if (q1.length >= 2) candidates.push(q1);
  if (q2.length >= 2 && q2.toLowerCase() !== q1.toLowerCase()) candidates.push(q2);
  if (q3.length >= 2 && q3.toLowerCase() !== q1.toLowerCase() && q3.toLowerCase() !== q2.toLowerCase()) {
    candidates.push(q3);
  }

  if (generic && dominantColor) {
    const withColor = sanitizeQuery([brand, modelExact, dominantColor].filter(Boolean).join(' '), brand);
    if (
      withColor.length >= 2 &&
      !candidates.some((c) => c.toLowerCase() === withColor.toLowerCase())
    ) {
      candidates.push(withColor);
    }
  }

  return { queries: dedupeQueries(candidates).slice(0, 3) };
}
