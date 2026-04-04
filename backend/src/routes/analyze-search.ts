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
import {
  buildGrailedSearchUrl,
  searchGrailedByText,
  type GrailedSearchItem,
} from '../services/grailed-text-search.js';
import type { MarketplaceListingDTO } from '../api/types.js';
import { visionProviderName, isDebug } from '../config.js';
import {
  GRAILED_MAX_PER_PAGE,
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

function countBySource(listings: MarketplaceListingDTO[]): Record<string, number> {
  const acc: Record<string, number> = {};
  for (const l of listings) {
    const s = (l.source ?? '').trim() || '(unknown)';
    acc[s] = (acc[s] ?? 0) + 1;
  }
  return acc;
}

function grailedItemsToListings(items: GrailedSearchItem[]): MarketplaceListingDTO[] {
  return items.map((item, index) => {
    const idMatch = item.listingUrl.match(/\/listings\/(\d+)/);
    const id = idMatch?.[1] ?? `grailed-${index}`;
    return {
      id,
      source: 'Grailed',
      title: item.title,
      price: item.price ?? 0,
      currency: item.currency ?? 'USD',
      imageUrl: item.imageUrl,
      thumbnailUrl: item.imageUrl,
      listingUrl: item.listingUrl,
      ...(item.brand ? { brand: item.brand } : {}),
      size: item.size,
    };
  });
}

async function fetchProviderPages<T>(
  provider: 'VINTED' | 'GRAILED',
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
      // eslint-disable-next-line no-console -- diagnostic pagination provider
      console.error(`[${provider}_PAGE_${page}_FAILED]`, err);
      break;
    }

    if (page === 1) {
      // eslint-disable-next-line no-console -- diagnostic pagination provider
      console.log(`[${provider}_PAGE_1_COUNT]`, pageItems.length);
    } else if (page === 2) {
      // eslint-disable-next-line no-console -- diagnostic pagination provider
      console.log(`[${provider}_PAGE_2_COUNT]`, pageItems.length);
    } else {
      // eslint-disable-next-line no-console -- diagnostic pagination provider
      console.log(`[${provider}_PAGE_N_COUNT]`, { page, count: pageItems.length });
    }

    if (pageItems.length === 0) break;
    out.push(...pageItems);

    if (out.length >= MAX_TOTAL_PER_PROVIDER) {
      // eslint-disable-next-line no-console -- diagnostic pagination provider
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

    // eslint-disable-next-line no-console -- traçage strict
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
      // eslint-disable-next-line no-console -- diagnostic taille
      console.warn('[PAYLOAD_TOO_LARGE]', imageBuffer.length);
      return reply.status(413).send({
        error: 'payload_too_large',
        message: 'Image payload too large',
      } as unknown as AnalyzeSearchResponse);
    }

    // eslint-disable-next-line no-console -- traçage strict
    console.log(`[VISION_PROVIDER_USED] ${visionProviderName}`);

    let visionResult: import('../api/types.js').FashionVisionResult;
    let rawOutput: string | undefined;

    try {
      const analyzed = await visionProvider.analyzeFashionItem(imageBuffer);
      visionResult = analyzed.visionResult;
      rawOutput = analyzed.rawOutput;
    } catch (err) {
      request.log.error(err, 'Vision provider failed');
      // eslint-disable-next-line no-console -- diagnostic OpenAI
      console.error('[OPENAI_VISION_FAILED]', err);
      return reply.status(502).send({
        error: 'openai_error',
        message: 'Vision analysis failed',
      } as unknown as AnalyzeSearchResponse);
    }

    // eslint-disable-next-line no-console -- traçage strict
    console.log('[RAW_VISION_OUTPUT]', rawOutput ?? '(none)');

    // eslint-disable-next-line no-console -- traçage strict
    console.log('[NORMALIZED_VISION_RESULT]', JSON.stringify(visionResult));

    const category = visionResult.category?.trim();
    if (!category) {
      // eslint-disable-next-line no-console -- filtre métier
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
      // eslint-disable-next-line no-console -- filtre qualité
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

    // eslint-disable-next-line no-console -- traçage strict
    console.log('[GENERATED_SEARCH_QUERIES]', JSON.stringify(generatedQueries));

    const primaryQuery =
      generatedQueries[0] ??
      visionResult.dominantItem ??
      visionResult.subcategory ??
      visionResult.category ??
      'fashion item';

    const trimmedPrimary = String(primaryQuery).trim();
    const vintedSearchUrl = buildVintedSearchUrl(trimmedPrimary);
    const grailedSearchUrl = buildGrailedSearchUrl(trimmedPrimary);
    // eslint-disable-next-line no-console -- diagnostic fusion marketplaces
    console.log('[ANALYZE_PRIMARY_QUERY]', trimmedPrimary);
    // eslint-disable-next-line no-console -- diagnostic fusion marketplaces
    console.log('[VINTED_SEARCH_URL]', vintedSearchUrl);
    // eslint-disable-next-line no-console -- diagnostic fusion marketplaces
    console.log('[GRAILED_SEARCH_URL]', grailedSearchUrl);
    // eslint-disable-next-line no-console -- diagnostic fusion marketplaces
    console.log('[MARKETPLACE_LIMITS]', {
      VINTED_MAX_PER_PAGE,
      GRAILED_MAX_PER_PAGE,
      VINTED_MAX_TOTAL_LISTINGS_HINT,
    });

    const vintedPaged = await fetchProviderPages<VintedSearchItem>(
      'VINTED',
      VINTED_MAX_PER_PAGE,
      (page) => searchVintedByText(trimmedPrimary, { page })
    );
    const grailedPaged = await fetchProviderPages<GrailedSearchItem>(
      'GRAILED',
      GRAILED_MAX_PER_PAGE,
      (page) => searchGrailedByText(trimmedPrimary, { page })
    );

    const vintedItems = vintedPaged.items;
    const grailedItems = grailedPaged.items;
    const vintedSearchFailed = vintedPaged.failed;
    const grailedSearchFailed = grailedPaged.failed;

    const vintedListings = vintedItemsToListings(vintedItems);
    const grailedListings = grailedItemsToListings(grailedItems);
    const merged = [...vintedListings, ...grailedListings];

    // eslint-disable-next-line no-console -- diagnostic fusion marketplaces
    console.log('VINTED_COUNT', vintedListings.length);
    // eslint-disable-next-line no-console -- diagnostic fusion marketplaces
    console.log('GRAILED_COUNT', grailedListings.length);
    // eslint-disable-next-line no-console -- diagnostic fusion marketplaces
    console.log('FINAL_COUNT', merged.length);
    // eslint-disable-next-line no-console -- diagnostic fusion marketplaces
    console.log(
      'BY_SOURCE',
      merged.reduce<Record<string, number>>((acc, x) => {
        acc[x.source] = (acc[x.source] || 0) + 1;
        return acc;
      }, {})
    );
    // eslint-disable-next-line no-console -- diagnostic fusion marketplaces
    console.log('[MERGED_COUNT]', merged.length);
    // eslint-disable-next-line no-console -- diagnostic fusion marketplaces
    console.log('[FINAL_LISTINGS_COUNT]', merged.length);
    // eslint-disable-next-line no-console -- diagnostic fusion marketplaces
    console.log('[LISTINGS_BY_SOURCE]', JSON.stringify(countBySource(merged)));

    const response: AnalyzeSearchResponse = {
      visionResult,
      generatedQueries,
      listings: merged,
      ...(vintedSearchFailed ? { vintedSearchFailed: true } : {}),
      ...(grailedSearchFailed ? { grailedSearchFailed: true } : {}),
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
