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
import type { MarketplaceListingDTO } from '../api/types.js';
import { visionProviderName, isDebug } from '../config.js';

const visionProvider =
  visionProviderName === 'openai' ? openaiVisionProvider : mockVisionProvider;

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

    // eslint-disable-next-line no-console -- traçage strict
    console.log(`[VISION_PROVIDER_USED] ${visionProviderName}`);

    try {
      const { visionResult, rawOutput } =
        await visionProvider.analyzeFashionItem(imageBuffer);



      // eslint-disable-next-line no-console -- traçage strict
      console.log('[RAW_VISION_OUTPUT]', rawOutput ?? '(none)');

      // eslint-disable-next-line no-console -- traçage strict
      console.log('[NORMALIZED_VISION_RESULT]', JSON.stringify(visionResult));

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
      // eslint-disable-next-line no-console -- traçage recherche Vinted
      console.log('[VINTED_PRIMARY_QUERY]', trimmedPrimary);
      // eslint-disable-next-line no-console -- traçage recherche Vinted
      console.log('[VINTED_SEARCH_URL]', vintedSearchUrl);

      let vintedItems: VintedSearchItem[] = [];
      try {
        vintedItems = await searchVintedByText(trimmedPrimary);
      } catch (vintedErr) {
        request.log.error(vintedErr, 'Vinted catalog fetch/parse failed');
        // eslint-disable-next-line no-console -- erreur métier
        console.error('[VINTED_SEARCH_FAILED]', vintedErr);
      }

      const listings = vintedItemsToListings(vintedItems);
      // eslint-disable-next-line no-console -- traçage strict
      console.log('[LISTINGS_COUNT]', listings.length);

      const response: AnalyzeSearchResponse = {
        visionResult,
        generatedQueries,
        listings,
        ...(isDebug && {
          debug: {
            visionProvider: visionProviderName,
            rawVisionOutput: rawOutput ?? JSON.stringify(visionResult),
            normalizedVisionResult: visionResult,
            generatedSearchQueries: generatedQueries,
          },
        }),
      };

      // eslint-disable-next-line no-console -- traçage strict
      console.log('[FINAL_RESPONSE_JSON]', JSON.stringify(response));

      return reply.send(response);
    } catch (err) {
      request.log.error(err, 'analyze-search failed');
      return reply.status(500).send({
        error: 'server_error',
        message: 'Analysis failed',
      } as unknown as AnalyzeSearchResponse);
    }
  });
}
