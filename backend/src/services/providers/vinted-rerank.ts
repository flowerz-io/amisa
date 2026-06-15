import type { FashionVisionResult, MarketplaceListingDTO } from '../../types.js';
import {
  geminiModelCandidates,
} from '../vision/gemini-provider.js';

function buildGeminiTextEndpoint(model: string, apiKey: string): string {
  return `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`;
}

export interface VintedRerankOptions {
  minScore?: number;
  useGemini?: boolean;
}

export interface VintedRerankResult {
  listings: MarketplaceListingDTO[];
  rawCount: number;
  acceptedCount: number;
  rejectedCount: number;
  noRelevantResults: boolean;
}

const DEFAULT_MIN_SCORE = 40;

/** Annonces manifestement hors mode / hors sujet. */
const NON_FASHION_RE =
  /\b(comic|comics|manga|marvel|dc\s+comics|figurine|funko|pokémon|pokemon|carte\s+à\s+collectionner|trading\s+card|livre|book|bd\b|bande\s+dessinée|numéro\s*\d|numero\s*\d|num\.\s*\d|dvd|blu-?ray|jeu\s+vidéo|playstation|xbox|nintendo|lego|puzzle|poster\s+affich|affiche\s+cinéma)\b/i;

const FASHION_POSITIVE_RE =
  /\b(sac|bag|sneaker|basket|chaussure|boot|botte|robe|dress|veste|jacket|coat|manteau|pantalon|jean|denim|pull|sweat|hoodie|t-?shirt|tee|chemise|shirt|jupe|skirt|ceinture|belt|bijou|jewel|montre|watch|lunettes|glasses|chaussures|sneakers|handbag|tote|clutch|wallet|portefeuille|cardigan|blazer|parka|gilet|cardigan)\b/i;

function minScoreFromEnv(override?: number): number {
  if (override != null && Number.isFinite(override)) return override;
  const n = Number(process.env.VINTED_MIN_RELEVANCE_SCORE?.trim() || String(DEFAULT_MIN_SCORE));
  return Number.isFinite(n) && n >= 0 ? n : DEFAULT_MIN_SCORE;
}

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((t) => t.length >= 2);
}

function overlapScore(tokensA: string[], tokensB: string[]): number {
  if (tokensA.length === 0 || tokensB.length === 0) return 0;
  const setB = new Set(tokensB);
  let hits = 0;
  for (const t of tokensA) {
    if (setB.has(t)) hits++;
  }
  return hits / Math.max(tokensA.length, 1);
}

function visionContext(vision: FashionVisionResult): {
  brand: string;
  model: string;
  category: string;
  colorway: string;
  identification: string;
  tokens: string[];
} {
  const brand = (vision.probableBrand ?? '').trim();
  const model = (vision.exactModel ?? vision.inferredModel ?? '').trim();
  const category = (vision.category ?? vision.itemTypeCanonical ?? '').trim();
  const colorway = (
    vision.colorway ??
    vision.dominantColorPrecise ??
    vision.color ??
    ''
  ).trim();
  const identification = (
    vision.fullIdentification ??
    vision.dominantItem ??
    [brand, model, colorway].filter(Boolean).join(' ')
  ).trim();

  const tokens = tokenize(
    [brand, model, category, colorway, identification].filter(Boolean).join(' ')
  );

  return { brand, model, category, colorway, identification, tokens };
}

export function scoreListingHeuristic(
  listing: MarketplaceListingDTO,
  vision: FashionVisionResult,
  queries: string[]
): number {
  const ctx = visionContext(vision);
  const title = listing.title ?? '';
  const brandField = listing.brand ?? '';
  const blob = `${title} ${brandField}`.trim();

  if (NON_FASHION_RE.test(blob)) return 0;

  const titleTokens = tokenize(blob);
  if (titleTokens.length === 0) return 0;

  let score = 0;

  const brandTok = tokenize(ctx.brand);
  if (brandTok.length > 0) {
    const brandHit = brandTok.some((t) => titleTokens.includes(t));
    if (brandHit) score += 25;
    else if (ctx.brand.length >= 4) score -= 8;
  }

  const modelTok = tokenize(ctx.model);
  if (modelTok.length > 0) {
    score += Math.round(overlapScore(modelTok, titleTokens) * 25);
  }

  const catTok = tokenize(ctx.category);
  if (catTok.length > 0) {
    score += Math.round(overlapScore(catTok, titleTokens) * 12);
  }
  if (FASHION_POSITIVE_RE.test(blob)) score += 6;

  const colorTok = tokenize(ctx.colorway);
  if (colorTok.length > 0) {
    score += Math.round(overlapScore(colorTok, titleTokens) * 12);
  }

  const queryTok = tokenize(queries.join(' '));
  if (queryTok.length > 0) {
    score += Math.round(overlapScore(queryTok, titleTokens) * 18);
  }

  score += Math.round(overlapScore(ctx.tokens, titleTokens) * 10);

  return Math.max(0, Math.min(100, Math.round(score)));
}

async function geminiRerankScores(
  vision: FashionVisionResult,
  listings: MarketplaceListingDTO[]
): Promise<Map<string, number> | null> {
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (!apiKey || listings.length === 0) return null;

  const ctx = visionContext(vision);
  const items = listings.slice(0, 30).map((L) => ({
    id: L.id,
    title: L.title.slice(0, 120),
    brand: L.brand ?? '',
  }));

  const prompt = `Tu es un expert mode/seconde main. Score chaque annonce Vinted (0-100) selon sa pertinence par rapport à l'article cible.

Article cible :
- identification: ${ctx.identification}
- marque: ${ctx.brand}
- modèle: ${ctx.model}
- catégorie: ${ctx.category}
- coloris: ${ctx.colorway}

Règles :
- 0 pour comics, livres, figurines, jeux, objets non-mode.
- 90+ si marque + modèle + catégorie correspondent clairement.
- 40-70 si partiellement pertinent (même marque ou même type).
- <20 si hors sujet (ex: Marvel alors que cible = sac Lemaire).

Annonces :
${JSON.stringify(items, null, 0)}

Réponds STRICTEMENT en JSON :
{"scores":[{"id":"...","score":0,"reason":"..."}]}`;

  const models = geminiModelCandidates();
  for (const model of models) {
    try {
      const endpoint = buildGeminiTextEndpoint(model, apiKey);
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.1, maxOutputTokens: 2048 },
        }),
      });
      if (!res.ok) continue;
      const payload = (await res.json()) as {
        candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
      };
      const raw = payload.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
      const start = raw.indexOf('{');
      const end = raw.lastIndexOf('}');
      if (start < 0 || end <= start) continue;
      const parsed = JSON.parse(raw.slice(start, end + 1)) as {
        scores?: Array<{ id?: string; score?: number }>;
      };
      const out = new Map<string, number>();
      for (const row of parsed.scores ?? []) {
        if (!row.id) continue;
        const n = Math.round(Number(row.score));
        out.set(row.id, Number.isFinite(n) ? Math.max(0, Math.min(100, n)) : 0);
      }
      if (out.size > 0) return out;
    } catch {
      continue;
    }
  }
  return null;
}

function useGeminiRerank(): boolean {
  const flag = process.env.VINTED_GEMINI_RERANK?.trim().toLowerCase();
  if (flag === 'false' || flag === '0') return false;
  return Boolean(process.env.GEMINI_API_KEY?.trim());
}

/**
 * Filtre et reclasse les annonces Vinted selon la vision Gemini + heuristiques.
 */
export async function rerankVintedListings(
  listings: MarketplaceListingDTO[],
  vision: FashionVisionResult,
  queries: string[],
  options?: VintedRerankOptions
): Promise<VintedRerankResult> {
  const rawCount = listings.length;
  if (rawCount === 0) {
    return {
      listings: [],
      rawCount: 0,
      acceptedCount: 0,
      rejectedCount: 0,
      noRelevantResults: false,
    };
  }

  const minScore = minScoreFromEnv(options?.minScore);
  const geminiScores =
    options?.useGemini !== false && useGeminiRerank()
      ? await geminiRerankScores(vision, listings)
      : null;

  console.log('[VINTED_RERANK]', {
    rawCount,
    minScore,
    gemini: geminiScores != null,
    identification: visionContext(vision).identification.slice(0, 80),
  });

  const scored: MarketplaceListingDTO[] = [];

  for (const listing of listings) {
    const heuristic = scoreListingHeuristic(listing, vision, queries);
    const gemini = geminiScores?.get(listing.id);
    const score =
      gemini != null
        ? Math.round(heuristic * 0.35 + gemini * 0.65)
        : heuristic;

    if (score < minScore) {
      console.log('[VINTED_REJECTED]', {
        title: listing.title.slice(0, 100),
        score,
        minScore,
        heuristic,
        gemini: gemini ?? null,
      });
      continue;
    }

    console.log('[VINTED_ACCEPTED]', {
      title: listing.title.slice(0, 100),
      score,
      heuristic,
      gemini: gemini ?? null,
    });

    scored.push({ ...listing, relevanceScore: score });
  }

  scored.sort((a, b) => (b.relevanceScore ?? 0) - (a.relevanceScore ?? 0));

  const noRelevantResults = rawCount > 0 && scored.length === 0;

  return {
    listings: scored,
    rawCount,
    acceptedCount: scored.length,
    rejectedCount: rawCount - scored.length,
    noRelevantResults,
  };
}
