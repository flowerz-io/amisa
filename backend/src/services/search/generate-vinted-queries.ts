export interface VintedQueryInput {
  brand: string;
  model: string;
  dominantColor: string;
}

export interface VintedQueryOutput {
  queries: string[];
}

/** Caractères interdits dans les requêtes Vinted (parenthèses, slashs). */
const FORBIDDEN_CHARS = /[()/\\]/g;

function cleanToken(value: string): string {
  return value
    .replace(FORBIDDEN_CHARS, ' ')
    .replace(/\s+/g, ' ')
    .trim();
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
 * Génère jusqu'à 3 requêtes Vinted courtes à partir de la vision Gemini.
 */
export function generateVintedQueries(input: VintedQueryInput): VintedQueryOutput {
  const brand = cleanToken(input.brand);
  const model = cleanToken(input.model);
  const color = cleanToken(input.dominantColor);

  if (!model) {
    return { queries: [] };
  }

  const q1 = [brand, model].filter(Boolean).join(' ').trim();
  const q2 = [brand, model, color].filter(Boolean).join(' ').trim();
  const q3 = model;

  const candidates: string[] = [];
  if (q1.length >= 2) candidates.push(q1);
  if (q2.length >= 2) candidates.push(q2);
  if (q3.length >= 2) candidates.push(q3);

  return { queries: dedupeQueries(candidates).slice(0, 3) };
}
