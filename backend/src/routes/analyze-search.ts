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
import {
  searchLeBonCoinByTextBrowser,
  type LeBonCoinSearchItem,
  buildLeBonCoinSearchUrl,
} from '../services/leboncoin-browser-search.js';
import { searchEbayByText, type EbaySearchItem, buildEbaySearchUrl } from '../services/ebay-text-search.js';
import type { MarketplaceListingDTO } from '../api/types.js';
import type { SearchRankingContextDTO } from '../api/types.js';
import { visionProviderName, isDebug } from '../config.js';
import { rankAcrossSources } from '../services/marketplace-ranking.js';
import { INITIAL_RETURN_PER_PROVIDER, NEXT_BATCH_PER_PROVIDER } from '../marketplace-limits.js';
import { isProviderEnabled } from '../providers-config.js';

const visionProvider =
  visionProviderName === 'openai' ? openaiVisionProvider : mockVisionProvider;

/** Limite côté appli (après décodage base64). Les clients ciblent ~500 Ko ; marge pour proxies. */
const MAX_IMAGE_BYTES = 6 * 1024 * 1024;
function extractHttpStatus(err: unknown): number | undefined {
  if (err instanceof Error) {
    const m = err.message.match(/HTTP\s+(\d{3})/i);
    if (m) return parseInt(m[1], 10);
  }
  return undefined;
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

function leBonCoinItemsToListings(items: LeBonCoinSearchItem[]): MarketplaceListingDTO[] {
  return items.map((item, index) => {
    const idFromUrl =
      item.listingUrl.match(/\/([0-9]{6,})\.htm/i)?.[1] ??
      item.listingUrl.match(/ad\/([0-9]{6,})/i)?.[1];
    const id =
      idFromUrl ??
      `leboncoin-${Buffer.from(item.listingUrl).toString('base64').replace(/[^a-zA-Z0-9]/g, '').slice(0, 18)}-${index}`;
    return {
      id,
      source: 'Le Bon Coin',
      title: item.title,
      price: item.price ?? 0,
      currency: item.currency ?? 'EUR',
      imageUrl: item.imageUrl,
      thumbnailUrl: item.thumbnailUrl ?? item.imageUrl,
      listingUrl: item.listingUrl,
      ...(item.brand ? { brand: item.brand } : {}),
      ...(item.size ? { size: item.size } : {}),
      ...(item.condition ? { condition: item.condition } : {}),
    };
  });
}

function ebayItemsToListings(items: EbaySearchItem[]): MarketplaceListingDTO[] {
  return items.map((item, index) => {
    const id =
      item.listingId ??
      item.listingUrl.match(/\/itm\/(?:[^/]*\/)?(\d{8,15})/i)?.[1] ??
      `ebay-${index}`;
    return {
      id,
      source: 'eBay',
      title: item.title,
      price: item.price ?? 0,
      currency: item.currency ?? 'EUR',
      imageUrl: item.imageUrl,
      thumbnailUrl: item.thumbnailUrl ?? item.imageUrl,
      listingUrl: item.listingUrl,
      ...(item.brand ? { brand: item.brand } : {}),
      ...(item.size ? { size: item.size } : {}),
      ...(item.condition ? { condition: item.condition } : {}),
      ...(item.publishedAtRelative ? { publishedAtRelative: item.publishedAtRelative } : {}),
    };
  });
}

export async function analyzeSearchRoute(app: FastifyInstance) {
  app.post<{
    Body: AnalyzeSearchRequest;
    Reply: AnalyzeSearchResponse;
  }>('/analyze-search', async (request, reply) => {
    const startedAt = Date.now();
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
    const vintedSearchUrl = buildVintedSearchUrl(trimmedPrimary, 1);
    const ebaySearchUrl = buildEbaySearchUrl(trimmedPrimary, 1);
    const leBonCoinSearchUrl = buildLeBonCoinSearchUrl(trimmedPrimary, 1);
    console.log('[ANALYZE_PRIMARY_QUERY]', trimmedPrimary);
    console.log('[VINTED_SEARCH_URL]', vintedSearchUrl);
    console.log('[EBAY_SEARCH_URL]', ebaySearchUrl);
    console.log('[LEBONCOIN_SEARCH_URL]', leBonCoinSearchUrl);
    const rankingContext: SearchRankingContextDTO = {
      primaryQuery: trimmedPrimary,
      probableBrand: visionResult.probableBrand,
      dominantColor: visionResult.dominantColorPrecise ?? visionResult.color,
      category: visionResult.category,
      subcategory: visionResult.subcategory,
      dominantItem: visionResult.dominantItem,
      inferredModel: visionResult.inferredModel,
      itemTypeCanonical: visionResult.itemTypeCanonical,
    };

    let vintedSearchFailed = false;
    let vintedItems: VintedSearchItem[] = [];
    try {
      vintedItems = await searchVintedByText(trimmedPrimary, { page: 1, limit: INITIAL_RETURN_PER_PROVIDER });
    } catch (err) {
      vintedSearchFailed = true;
      const status = extractHttpStatus(err);
      if (status === 403) {
        console.log('VINTED_BLOCKED', { page: 1, query: trimmedPrimary.slice(0, 120) });
      }
      request.log.error(err, 'Vinted initial fetch failed');
    }
    const vintedListings = vintedItemsToListings(vintedItems);
    const vintedHasMore = vintedItems.length >= INITIAL_RETURN_PER_PROVIDER;
    const vintedStopReason = vintedHasMore ? 'initial_batch_reached' : 'provider_exhausted_on_page_1';
    console.log('VINTED_INITIAL_COUNT', vintedListings.length);
    console.log('CURRENT_VINTED_PAGE', 1);
    console.log('TOTAL_LOADED_VINTED', vintedListings.length);
    console.log('VINTED_STOP_REASON', vintedStopReason);

    let grailedListings: MarketplaceListingDTO[] = [];
    try {
      grailedListings = await searchGrailedByTextBrowser(trimmedPrimary, { page: 1, limit: INITIAL_RETURN_PER_PROVIDER });
    } catch (err) {
      request.log.error(err, 'Grailed initial fetch failed');
      grailedListings = [];
    }
    const grailedHasMore = grailedListings.length >= INITIAL_RETURN_PER_PROVIDER;
    const grailedStopReason = grailedHasMore ? 'initial_batch_reached' : 'provider_exhausted_on_page_1';
    console.log('GRAILED_INITIAL_COUNT', grailedListings.length);
    console.log('CURRENT_GRAILED_PAGE', 1);
    console.log('TOTAL_LOADED_GRAILED', grailedListings.length);
    console.log('GRAILED_STOP_REASON', grailedStopReason);

    let ebaySearchFailed = false;
    let ebayItems: EbaySearchItem[] = [];
    let ebayTotalCount: number | undefined;
    if (!isProviderEnabled('ebay')) {
      console.log('[EBAY_DISABLED] provider skipped');
    } else {
      try {
        const result = await searchEbayByText(trimmedPrimary, {
          page: 1,
          limit: INITIAL_RETURN_PER_PROVIDER,
        });
        ebayItems = result.items;
        ebayTotalCount = result.totalCount;
      } catch (err) {
        ebaySearchFailed = true;
        request.log.error(err, 'eBay initial fetch failed');
      }
    }
    const ebayListings = ebayItemsToListings(ebayItems);
    const ebayHasMore = ebayItems.length >= INITIAL_RETURN_PER_PROVIDER || (ebayItems.length === 0 && (ebayTotalCount ?? 0) > 0);
    const ebayStopReason = ebayItems.length >= INITIAL_RETURN_PER_PROVIDER
      ? 'initial_batch_reached'
      : (ebayItems.length === 0 && (ebayTotalCount ?? 0) > 0)
          ? 'parse_failed_page_1_total_detected'
          : 'provider_exhausted_on_page_1';
    console.log('[EBAY_INITIAL_COUNT]', ebayListings.length);
    console.log('[CURRENT_EBAY_PAGE]', 1);
    console.log('[TOTAL_LOADED_EBAY]', ebayListings.length);
    console.log('[EBAY_STOP_REASON]', ebayStopReason);
    if (ebayTotalCount !== undefined) {
      console.log('[EBAY_TOTAL_COUNT]', ebayTotalCount);
    }

    let leboncoinSearchFailed = false;
    let leboncoinItems: LeBonCoinSearchItem[] = [];
    let leboncoinTotalCount: number | undefined;
    if (!isProviderEnabled('leboncoin')) {
      console.log('[LEBONCOIN_DISABLED] anti-bot challenge detected, provider skipped');
    } else {
      try {
        const result = await searchLeBonCoinByTextBrowser(trimmedPrimary, {
          page: 1,
          limit: INITIAL_RETURN_PER_PROVIDER,
        });
        leboncoinItems = result.items;
        leboncoinTotalCount = result.totalCount;
      } catch (err) {
        leboncoinSearchFailed = true;
        request.log.error(err, 'Le Bon Coin initial fetch failed');
      }
    }
    const leboncoinListings = leBonCoinItemsToListings(leboncoinItems);
    const leboncoinHasMore = leboncoinItems.length >= INITIAL_RETURN_PER_PROVIDER;
    const leboncoinStopReason = leboncoinHasMore
      ? 'initial_batch_reached'
      : 'provider_exhausted_on_page_1';
    console.log('LEBONCOIN_INITIAL_COUNT', leboncoinListings.length);
    console.log('CURRENT_LEBONCOIN_PAGE', 1);
    console.log('TOTAL_LOADED_LEBONCOIN', leboncoinListings.length);
    console.log('LEBONCOIN_STOP_REASON', leboncoinStopReason);
    if (leboncoinTotalCount !== undefined) {
      console.log('[LEBONCOIN_TOTAL_COUNT]', leboncoinTotalCount);
    }

    const mergedInitial = [...vintedListings, ...grailedListings, ...ebayListings, ...leboncoinListings];
    const ranked = rankAcrossSources(mergedInitial, rankingContext);
    console.log('INITIAL_MERGED_COUNT', ranked.length);
    console.log('FINAL_COUNT', ranked.length);
    console.log('BY_SOURCE', JSON.stringify(countBySource(ranked)));
    console.log('INITIAL_RESPONSE_TIME_MS', Date.now() - startedAt);

    const response: AnalyzeSearchResponse = {
      visionResult,
      generatedQueries,
      listings: ranked,
      pagination: {
        primaryQuery: trimmedPrimary,
        batchSizePerProvider: NEXT_BATCH_PER_PROVIDER,
        vinted: {
          nextPage: 2,
          hasMore: vintedHasMore,
          loadedCount: vintedListings.length,
        },
        grailed: {
          nextPage: 2,
          hasMore: grailedHasMore,
          loadedCount: grailedListings.length,
        },
        ebay: {
          nextPage: 2,
          hasMore: ebayHasMore,
          loadedCount: ebayListings.length,
        },
        leboncoin: {
          nextPage: 2,
          hasMore: leboncoinHasMore,
          loadedCount: leboncoinListings.length,
        },
      },
      rankingContext,
      ...(vintedSearchFailed ? { vintedSearchFailed: true } : {}),
      ...(ebaySearchFailed ? { ebaySearchFailed: true } : {}),
      ...(leboncoinSearchFailed ? { leboncoinSearchFailed: true } : {}),
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
