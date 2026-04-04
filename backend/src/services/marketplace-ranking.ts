import type { MarketplaceListingDTO, SearchRankingContextDTO } from '../api/types.js';

const STOPWORDS = new Set([
  'de', 'des', 'du', 'la', 'le', 'les', 'et', 'or', 'the', 'a', 'an', 'for', 'with',
]);

function normalize(s: string | undefined): string {
  return (s ?? '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function tokenize(s: string | undefined): string[] {
  const n = normalize(s);
  if (!n) return [];
  return n.split(' ').filter((x) => x.length >= 3 && !STOPWORDS.has(x));
}

function containsPhrase(haystack: string, phrase: string): boolean {
  const p = normalize(phrase);
  return !!p && haystack.includes(p);
}

function parseRelativeAgeDays(raw: string | undefined): number | undefined {
  if (!raw) return undefined;
  const t = normalize(raw);
  if (!t) return undefined;
  if (t.includes('just now') || t.includes('today')) return 0;
  if (t.includes('yesterday')) return 1;
  const m = t.match(/(\d+)\s+(minute|hour|day|week|month|year)s?\s+ago/);
  if (!m) return undefined;
  const n = parseInt(m[1], 10);
  if (!Number.isFinite(n)) return undefined;
  switch (m[2]) {
    case 'minute': return 0;
    case 'hour': return 0;
    case 'day': return n;
    case 'week': return n * 7;
    case 'month': return n * 30;
    case 'year': return n * 365;
    default: return undefined;
  }
}

type Ranked = {
  listing: MarketplaceListingDTO;
  score: number;
  recencyDays?: number;
  index: number;
};

export function scoreListing(
  listing: MarketplaceListingDTO,
  ctx: SearchRankingContextDTO
): { score: number; recencyDays?: number } {
  const titleNorm = normalize(listing.title);
  const brandNorm = normalize(listing.brand);
  const haystack = `${titleNorm} ${brandNorm}`.trim();
  let score = 0;

  const targetBrand = normalize(ctx.probableBrand);
  if (targetBrand) {
    if (brandNorm === targetBrand) score += 40;
    else if (containsPhrase(haystack, targetBrand)) score += 22;
  }

  const modelCandidates = [ctx.inferredModel, ctx.itemTypeCanonical, ctx.dominantItem, ctx.subcategory]
    .map(normalize)
    .filter(Boolean);
  let modelHits = 0;
  for (const phrase of modelCandidates) {
    if (containsPhrase(haystack, phrase)) modelHits += 1;
  }
  score += Math.min(modelHits * 12, 30);

  const color = normalize(ctx.dominantColor);
  if (color && containsPhrase(haystack, color)) score += 10;

  const keywords = tokenize(ctx.primaryQuery);
  let keywordHits = 0;
  for (const kw of keywords) {
    if (containsPhrase(haystack, kw)) keywordHits += 1;
  }
  score += Math.min(keywordHits * 4, 28);

  const category = normalize(ctx.category);
  const subcategory = normalize(ctx.subcategory);
  if (category && containsPhrase(haystack, category)) score += 8;
  if (subcategory && containsPhrase(haystack, subcategory)) score += 10;
  if (keywords.length > 0 && keywordHits === keywords.length) score += 12;

  const recencyDays = parseRelativeAgeDays(listing.publishedAtRelative);
  if (recencyDays !== undefined) {
    if (recencyDays <= 7) score += 6;
    else if (recencyDays <= 30) score += 3;
    else if (recencyDays <= 90) score += 1;
  }
  return { score, recencyDays };
}

export function rankAcrossSources(
  listings: MarketplaceListingDTO[],
  ctx: SearchRankingContextDTO
): MarketplaceListingDTO[] {
  const ranked: Ranked[] = listings.map((listing, index) => {
    const { score, recencyDays } = scoreListing(listing, ctx);
    return {
      listing: { ...listing, relevanceScore: score },
      score,
      recencyDays,
      index,
    };
  });

  ranked.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    const aDays = a.recencyDays ?? Number.POSITIVE_INFINITY;
    const bDays = b.recencyDays ?? Number.POSITIVE_INFINITY;
    if (aDays !== bDays) return aDays - bDays;
    return a.index - b.index;
  });

  return ranked.map((x) => x.listing);
}

