import { FastifyInstance } from 'fastify';
import type {
  MarketplaceListingDTO,
  SearchMoreRequest,
  SearchMoreResponse,
} from '../api/types.js';
import { searchVintedByText, type VintedSearchItem } from '../services/vinted-text-search.js';
import { searchGrailedByTextBrowser } from '../services/grailed-browser-search.js';
import { rankAcrossSources } from '../services/marketplace-ranking.js';

const DEFAULT_BATCH_SIZE = 50;

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

export async function searchMoreRoute(app: FastifyInstance) {
  app.post<{
    Body: SearchMoreRequest;
    Reply: SearchMoreResponse;
  }>('/search-more', async (request, reply) => {
    const startedAt = Date.now();
    const body = request.body;
    if (!body?.primaryQuery || typeof body.primaryQuery !== 'string') {
      return reply.status(400).send({
        error: 'primaryQuery is required',
      } as unknown as SearchMoreResponse);
    }
    if (!body.pagination) {
      return reply.status(400).send({
        error: 'pagination is required',
      } as unknown as SearchMoreResponse);
    }
    if (!body.rankingContext) {
      return reply.status(400).send({
        error: 'rankingContext is required',
      } as unknown as SearchMoreResponse);
    }

    const query = body.primaryQuery.trim();
    const batchSize = Math.max(1, Math.min(100, Math.floor(body.batchSizePerProvider ?? body.pagination.batchSizePerProvider ?? DEFAULT_BATCH_SIZE)));
    console.log('SEARCH_MORE_TRIGGERED', {
      query: query.slice(0, 120),
      batchSize,
      vintedNextPage: body.pagination.vinted.nextPage,
      grailedNextPage: body.pagination.grailed.nextPage,
      hasMoreVinted: body.pagination.vinted.hasMore,
      hasMoreGrailed: body.pagination.grailed.hasMore,
    });

    const nextVinted: MarketplaceListingDTO[] = [];
    let vintedPage = Math.max(1, body.pagination.vinted.nextPage);
    let hasMoreVinted = body.pagination.vinted.hasMore;
    if (hasMoreVinted) {
      while (nextVinted.length < batchSize) {
        const remaining = batchSize - nextVinted.length;
        const pageItems = await searchVintedByText(query, { page: vintedPage, limit: remaining });
        const mapped = vintedItemsToListings(pageItems);
        nextVinted.push(...mapped);
        console.log('CURRENT_VINTED_PAGE', vintedPage);
        if (pageItems.length < remaining) {
          hasMoreVinted = false;
          console.log('VINTED_STOP_REASON', 'provider_exhausted');
          break;
        }
        vintedPage += 1;
      }
      if (nextVinted.length >= batchSize) {
        console.log('VINTED_STOP_REASON', 'batch_reached');
      }
    } else {
      console.log('VINTED_STOP_REASON', 'already_exhausted');
    }

    const nextGrailed: MarketplaceListingDTO[] = [];
    let grailedPage = Math.max(1, body.pagination.grailed.nextPage);
    let hasMoreGrailed = body.pagination.grailed.hasMore;
    if (hasMoreGrailed) {
      while (nextGrailed.length < batchSize) {
        const remaining = batchSize - nextGrailed.length;
        const pageItems = await searchGrailedByTextBrowser(query, { page: grailedPage, limit: remaining });
        nextGrailed.push(...pageItems);
        console.log('CURRENT_GRAILED_PAGE', grailedPage);
        if (pageItems.length < remaining) {
          hasMoreGrailed = false;
          console.log('GRAILED_STOP_REASON', 'provider_exhausted');
          break;
        }
        grailedPage += 1;
      }
      if (nextGrailed.length >= batchSize) {
        console.log('GRAILED_STOP_REASON', 'batch_reached');
      }
    } else {
      console.log('GRAILED_STOP_REASON', 'already_exhausted');
    }

    console.log('VINTED_NEXT_BATCH_COUNT', nextVinted.length);
    console.log('GRAILED_NEXT_BATCH_COUNT', nextGrailed.length);

    const merged = rankAcrossSources([...nextVinted, ...nextGrailed], body.rankingContext);
    console.log('MERGED_NEXT_BATCH_COUNT', merged.length);
    console.log('TOTAL_LOADED_VINTED', body.pagination.vinted.loadedCount + nextVinted.length);
    console.log('TOTAL_LOADED_GRAILED', body.pagination.grailed.loadedCount + nextGrailed.length);
    console.log('HAS_MORE_VINTED', hasMoreVinted);
    console.log('HAS_MORE_GRAILED', hasMoreGrailed);
    console.log('NEXT_RESPONSE_TIME_MS', Date.now() - startedAt);

    return reply.send({
      listings: merged,
      vintedListings: nextVinted,
      grailedListings: nextGrailed,
      pagination: {
        primaryQuery: query,
        batchSizePerProvider: batchSize,
        vinted: {
          nextPage: vintedPage,
          hasMore: hasMoreVinted,
          loadedCount: body.pagination.vinted.loadedCount + nextVinted.length,
        },
        grailed: {
          nextPage: grailedPage,
          hasMore: hasMoreGrailed,
          loadedCount: body.pagination.grailed.loadedCount + nextGrailed.length,
        },
      },
      hasMoreVinted,
      hasMoreGrailed,
    });
  });
}

