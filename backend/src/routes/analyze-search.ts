import { FastifyInstance } from 'fastify';
import type { AnalyzeSearchRequest, AnalyzeSearchResponse } from '../api/types.js';
import { mockVisionProvider } from '../vision/mock-provider.js';
import { openaiVisionProvider } from '../vision/openai-provider.js';
import { generateSearchQueriesFromVision } from '../services/search-query-generator.js';
import {
  buildVintedSearchUrl,
  searchVintedByText,
  type VintedSearchItem,
} from '../services/vinted-text-search.js';
import { searchGrailedByTextBrowser } from '../services/grailed-browser-search.js';
import type { MarketplaceListingDTO } from '../api/types.js';
import { visionProviderName, isDebug } from '../config.js';
import {
  VINTED_MAX_PER_PAGE,
  VINTED_MAX_TOTAL_LISTINGS_HINT,
} from '../marketplace-limits.js';

const visionProvider =
  visionProviderName === 'openai' ? openaiVisionProvider : mockVisionProvider;

/** Limite côté appli (après décodage base64). Les clients ciblent ~500 Ko ; marge pour proxies. */
const MAX_IMAGE_BYTES = 6 * 1024 * 1024;
const MAX_PAGES_PER_PROVIDER = Math.max(1, Math.floor(Number(process.env.MARKETPLACE_MAX_PAGES ?? 40)));
const MAX_TOTAL_PER_PROVIDER =
  Number(process.env.MARKETPLACE_MAX_TOTAL_PER_PROVIDER ?? 0) > 0
    ? Math.floor(Number(process.env.MARKETPLACE_MAX_TOTAL_PER_PROVIDER))
    : Number.POSITIVE_INFINITY;

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

function countBySource(listings: MarketplaceListingDTO[]): Record<string, number> {
  const acc: Record<string, number> = {};
  for (const l of listings) {
    const s = (l.source ?? '').trim() || '(unknown)';
    acc[s] = (acc[s] ?? 0) + 1;
  }
  return acc;
}

function vintedItemsToListings(items: VintedSearchItem[]): MarketplaceListingDTO[] {
  return items.map((item, index) => {
    const idMatch = item.listingUrl.match(/\/items\/(\d+)/);
    const id = idMatch?.[1] ?? `vinted-${index}`;
    return {
      id,
      source: 'Vinted',
      title: item.title,
      price: item.price ?? 0,
      currency: item.currency ?? 'EUR',
      imageUrl: item.imageUrl,
      thumbnailUrl: item.imageUrl,
      listingUrl: item.listingUrl,
      ...(item.brand ? { brand: item.brand } : {}),
      size: item.size,
      condition: item.condition,
    };
  });
}

type RankingContext = {
  primaryQuery: string;
  probableBrand?: string;
  dominantColor?: string;
  category?: string;
  subcategory?: string;
  dominantItem?: string;
  inferredModel?: string;
  itemTypeCanonical?: string;
};

function scoreListing(listing: MarketplaceListingDTO, ctx: RankingContext): { score: number; recencyDays?: number } {
  const titleNorm = normalize(listing.title);
  const brandNorm = normalize(listing.brand);
  const haystack = `${titleNorm} ${brandNorm}`.trim();
  let score = 0;

  // 1) Marque exacte
  const targetBrand = normalize(ctx.probableBrand);
  if (targetBrand) {
    if (brandNorm === targetBrand) score += 40;
    else if (containsPhrase(haystack, targetBrand)) score += 22;
  }

  // 2) Modèle / type
  const modelCandidates = [ctx.inferredModel, ctx.itemTypeCanonical, ctx.dominantItem, ctx.subcategory]
    .map(normalize)
    .filter(Boolean);
  let modelHits = 0;
  for (const phrase of modelCandidates) {
    if (containsPhrase(haystack, phrase)) modelHits += 1;
  }
  score += Math.min(modelHits * 12, 30);

  // 3) Couleur
  const color = normalize(ctx.dominantColor);
  if (color && containsPhrase(haystack, color)) score += 10;

  // 4) Mots-clés principaux query
  const keywords = tokenize(ctx.primaryQuery);
  let keywordHits = 0;
  for (const kw of keywords) {
    if (containsPhrase(haystack, kw)) keywordHits += 1;
  }
  score += Math.min(keywordHits * 4, 28);

  // 5) Catégorie / sous-catégorie
  const category = normalize(ctx.category);
  const subcategory = normalize(ctx.subcategory);
  if (category && containsPhrase(haystack, category)) score += 8;
  if (subcategory && containsPhrase(haystack, subcategory)) score += 10;

  // 6) Bonus tous mots clés
  if (keywords.length > 0 && keywordHits === keywords.length) score += 12;

  // 7) Bonus léger récence
  const recencyDays = parseRelativeAgeDays(listing.publishedAtRelative);
  if (recencyDays !== undefined) {
    if (recencyDays <= 7) score += 6;
    else if (recencyDays <= 30) score += 3;
    else if (recencyDays <= 90) score += 1;
  }

  return { score, recencyDays };
}

function rankAcrossSources(listings: MarketplaceListingDTO[], ctx: RankingContext): MarketplaceListingDTO[] {
  const ranked = listings.map((listing, index) => {
    const { score, recencyDays } = scoreListing(listing, ctx);
    return { listing, score, recencyDays, index };
  });

  ranked.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    const aDays = a.recencyDays ?? Number.POSITIVE_INFINITY;
    const bDays = b.recencyDays ?? Number.POSITIVE_INFINITY;
    if (aDays !== bDays) return aDays - bDays;
    return a.index - b.index;
  });

  console.log(
    '[RANKED_TOP5]',
    ranked.slice(0, 5).map((x) => ({
      source: x.listing.source,
      title: x.listing.title,
      score: x.score,
      recencyDays: x.recencyDays,
      publishedAtRelative: x.listing.publishedAtRelative,
    }))
  );

  return ranked.map((x) => x.listing);
}

async function fetchProviderPages<T>(
  provider: 'VINTED',
  perPage: number,
  fetchPage: (page: number) => Promise<T[]>
): Promise<{ items: T[]; failed: boolean }> {
  const out: T[] = [];
  let failed = false;

  for (let page = 1; page <= MAX_PAGES_PER_PROVIDER; page++) {
    let pageItems: T[] = [];
    try {
      pageItems = await fetchPage(page);
    } catch (err) {
      failed = true;
      console.error(`[${provider}_PAGE_${page}_FAILED]`, err);
      break;
    }

    if (page === 1) {
      console.log(`[${provider}_PAGE_1_COUNT]`, pageItems.length);
    } else if (page === 2) {
      console.log(`[${provider}_PAGE_2_COUNT]`, pageItems.length);
    } else {
      console.log(`[${provider}_PAGE_N_COUNT]`, { page, count: pageItems.length });
    }

    if (pageItems.length === 0) break;
    out.push(...pageItems);

    if (out.length >= MAX_TOTAL_PER_PROVIDER) {
      console.log(`[${provider}_TOTAL_CAP_REACHED]`, {
        cap: MAX_TOTAL_PER_PROVIDER,
        collected: out.length,
      });
      break;
    }

    if (pageItems.length < perPage) break;
  }

  return { items: out, failed };
}

export async function analyzeSearchRoute(app: FastifyInstance) {
  app.post<{
    Body: AnalyzeSearchRequest;
    Reply: AnalyzeSearchResponse;
  }>('/analyze-search', async (request, reply) => {
    const body = request.body;

    console.log('[ANALYZE_REQUEST_RECEIVED]');

    if (!body?.imageBase64 || typeof body.imageBase64 !== 'string') {
      return reply.status(400).send({
        error: 'imageBase64 is required and must be a base64 string',
      } as unknown as AnalyzeSearchResponse);
    }

    const imageBuffer = Buffer.from(body.imageBase64, 'base64');
    if (imageBuffer.length === 0) {
      return reply
        .status(400)
        .send({ error: 'Invalid base64 image data' } as unknown as AnalyzeSearchResponse);
    }

    if (imageBuffer.length > MAX_IMAGE_BYTES) {
      console.warn('[PAYLOAD_TOO_LARGE]', imageBuffer.length);
      return reply.status(413).send({
        error: 'payload_too_large',
        message: 'Image payload too large',
      } as unknown as AnalyzeSearchResponse);
    }

    console.log(`[VISION_PROVIDER_USED] ${visionProviderName}`);

    let visionResult: import('../api/types.js').FashionVisionResult;
    let rawOutput: string | undefined;

    try {
      const analyzed = await visionProvider.analyzeFashionItem(imageBuffer);
      visionResult = analyzed.visionResult;
      rawOutput = analyzed.rawOutput;
    } catch (err) {
      request.log.error(err, 'Vision provider failed');
      console.error('[OPENAI_VISION_FAILED]', err);
      return reply.status(502).send({
        error: 'openai_error',
        message: 'Vision analysis failed',
      } as unknown as AnalyzeSearchResponse);
    }

    console.log('[RAW_VISION_OUTPUT]', rawOutput ?? '(none)');
    console.log('[NORMALIZED_VISION_RESULT]', JSON.stringify(visionResult));

    const category = visionResult.category?.trim();
    if (!category) {
      console.log('[ANALYSIS_REJECTED_NON_FASHION]');
      return reply.status(422).send({
        error: 'non_fashion',
        message: 'No clear fashion item detected',
      } as unknown as AnalyzeSearchResponse);
    }

    const { confidence, sourceConfidence } = visionResult;
    if (
      (confidence !== undefined && confidence < 0.6) ||
      (sourceConfidence !== undefined && sourceConfidence < 0.6)
    ) {
      console.log(
        '[ANALYSIS_REJECTED_LOW_CONFIDENCE]',
        JSON.stringify({ confidence, sourceConfidence })
      );
      return reply.status(422).send({
        error: 'low_confidence',
        message: 'Analysis confidence too low',
      } as unknown as AnalyzeSearchResponse);
    }

    const generatedQueries = generateSearchQueriesFromVision(visionResult, 3);
    console.log('[GENERATED_SEARCH_QUERIES]', JSON.stringify(generatedQueries));

    const primaryQuery =
      generatedQueries[0] ??
      visionResult.dominantItem ??
      visionResult.subcategory ??
      visionResult.category ??
      'fashion item';

    const trimmedPrimary = String(primaryQuery).trim();
    const vintedSearchUrl = buildVintedSearchUrl(trimmedPrimary);
    console.log('[ANALYZE_PRIMARY_QUERY]', trimmedPrimary);
    console.log('[VINTED_SEARCH_URL]', vintedSearchUrl);
    console.log('[MARKETPLACE_LIMITS]', { VINTED_MAX_PER_PAGE, VINTED_MAX_TOTAL_LISTINGS_HINT });

    const vintedPaged = await fetchProviderPages<VintedSearchItem>(
      'VINTED',
      VINTED_MAX_PER_PAGE,
      (page) => searchVintedByText(trimmedPrimary, { page })
    );
    const vintedItems = vintedPaged.items;
    const vintedSearchFailed = vintedPaged.failed;

    const grailedListings = await searchGrailedByTextBrowser(trimmedPrimary);
    const vintedListings = vintedItemsToListings(vintedItems);
    const merged = [...vintedListings, ...grailedListings];

    const ranked = rankAcrossSources(merged, {
      primaryQuery: trimmedPrimary,
      probableBrand: visionResult.probableBrand,
      dominantColor: visionResult.dominantColorPrecise ?? visionResult.color,
      category: visionResult.category,
      subcategory: visionResult.subcategory,
      dominantItem: visionResult.dominantItem,
      inferredModel: visionResult.inferredModel,
      itemTypeCanonical: visionResult.itemTypeCanonical,
    });

    console.log('VINTED_COUNT', vintedListings.length);
    console.log('GRAILED_COUNT', grailedListings.length);
    console.log('FINAL_COUNT', ranked.length);
    console.log(
      'BY_SOURCE',
      ranked.reduce<Record<string, number>>((acc, x) => {
        acc[x.source] = (acc[x.source] || 0) + 1;
        return acc;
      }, {})
    );
    console.log('[MERGED_COUNT]', ranked.length);
    console.log('[FINAL_LISTINGS_COUNT]', ranked.length);
    console.log('[LISTINGS_BY_SOURCE]', JSON.stringify(countBySource(ranked)));

    const response: AnalyzeSearchResponse = {
      visionResult,
      generatedQueries,
      listings: ranked,
      ...(vintedSearchFailed ? { vintedSearchFailed: true } : {}),
      ...(isDebug && {
        debug: {
          visionProvider: visionProviderName,
          rawVisionOutput: rawOutput ?? JSON.stringify(visionResult),
          normalizedVisionResult: visionResult,
          generatedSearchQueries: generatedQueries,
        },
      }),
    };

    return reply.send(response);
  });
}
