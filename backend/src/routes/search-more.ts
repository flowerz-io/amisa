import { FastifyInstance } from 'fastify';
import type {
  MarketplaceListingDTO,
  SearchMoreRequest,
  SearchMoreResponse,
} from '../api/types.js';
import { searchVintedByText, type VintedSearchItem } from '../services/vinted-text-search.js';
import { searchGrailedByTextBrowser } from '../services/grailed-browser-search.js';
import { rankAcrossSources } from '../services/marketplace-ranking.js';
import {
  GRAILED_MAX_PER_PAGE,
  MAX_PAGES_PER_PROVIDER,
  NEXT_BATCH_PER_PROVIDER,
  VINTED_MAX_PER_PAGE,
} from '../marketplace-limits.js';

const DEFAULT_BATCH_SIZE = NEXT_BATCH_PER_PROVIDER;

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

function extractHttpStatus(err: unknown): number | undefined {
  if (err instanceof Error) {
    const m = err.message.match(/HTTP\s+(\d{3})/i);
    if (m) return parseInt(m[1], 10);
  }
  return undefined;
}

function dedupePush(target: MarketplaceListingDTO[], incoming: MarketplaceListingDTO[]): number {
  const seen = new Set(target.map((x) => `${x.source}|${x.listingUrl ?? ''}|${x.id}`));
  let added = 0;
  for (const x of incoming) {
    const key = `${x.source}|${x.listingUrl ?? ''}|${x.id}`;
    if (seen.has(key)) continue;
    seen.add(key);
    target.push(x);
    added += 1;
  }
  return added;
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
    const batchSize = Math.max(1, Math.min(120, Math.floor(body.batchSizePerProvider ?? body.pagination.batchSizePerProvider ?? DEFAULT_BATCH_SIZE)));
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
    let vintedStopReason = 'already_exhausted';
    let vintedPagesFetched = 0;
    if (hasMoreVinted) {
      while (nextVinted.length < batchSize && vintedPagesFetched < MAX_PAGES_PER_PROVIDER) {
        const remaining = batchSize - nextVinted.length;
        const pageLimit = Math.max(1, Math.min(VINTED_MAX_PER_PAGE, remaining));
        let pageItems: VintedSearchItem[] = [];
        try {
          pageItems = await searchVintedByText(query, { page: vintedPage, limit: pageLimit });
        } catch (err) {
          const status = extractHttpStatus(err);
          if (status === 403) {
            console.log('VINTED_BLOCKED', { page: vintedPage, query: query.slice(0, 120) });
            vintedStopReason = 'blocked_403';
          } else {
            vintedStopReason = 'provider_error';
            request.log.error(err, 'Vinted pagination failed');
          }
          hasMoreVinted = false;
          break;
        }
        const mapped = vintedItemsToListings(pageItems);
        const added = dedupePush(nextVinted, mapped);
        console.log('CURRENT_VINTED_PAGE', vintedPage);
        vintedPagesFetched += 1;

        if (pageItems.length === 0) {
          hasMoreVinted = false;
          vintedStopReason = 'page_empty';
          break;
        }
        if (added === 0) {
          hasMoreVinted = false;
          vintedStopReason = 'no_new_unique_on_page';
          break;
        }
        if (pageItems.length < pageLimit) {
          hasMoreVinted = false;
          vintedStopReason = 'provider_exhausted';
          break;
        }
        vintedPage += 1;
      }
      if (hasMoreVinted && nextVinted.length >= batchSize) {
        vintedStopReason = 'batch_reached';
      } else if (hasMoreVinted && vintedPagesFetched >= MAX_PAGES_PER_PROVIDER) {
        hasMoreVinted = false;
        vintedStopReason = 'max_pages_reached';
      }
    }
    console.log('VINTED_STOP_REASON', vintedStopReason);

    const nextGrailed: MarketplaceListingDTO[] = [];
    let grailedPage = Math.max(1, body.pagination.grailed.nextPage);
    let hasMoreGrailed = body.pagination.grailed.hasMore;
    let grailedStopReason = 'already_exhausted';
    let grailedPagesFetched = 0;
    if (hasMoreGrailed) {
      while (nextGrailed.length < batchSize && grailedPagesFetched < MAX_PAGES_PER_PROVIDER) {
        const remaining = batchSize - nextGrailed.length;
        const pageLimit = Math.max(1, Math.min(GRAILED_MAX_PER_PAGE, remaining));
        let pageItems: MarketplaceListingDTO[] = [];
        try {
          pageItems = await searchGrailedByTextBrowser(query, { page: grailedPage, limit: pageLimit });
        } catch (err) {
          hasMoreGrailed = false;
          grailedStopReason = 'provider_error';
          request.log.error(err, 'Grailed pagination failed');
          break;
        }
        const added = dedupePush(nextGrailed, pageItems);
        console.log('CURRENT_GRAILED_PAGE', grailedPage);
        grailedPagesFetched += 1;

        if (pageItems.length === 0) {
          hasMoreGrailed = false;
          grailedStopReason = 'page_empty';
          break;
        }
        if (added === 0) {
          hasMoreGrailed = false;
          grailedStopReason = 'no_new_unique_on_page';
          break;
        }
        if (pageItems.length < pageLimit) {
          hasMoreGrailed = false;
          grailedStopReason = 'provider_exhausted';
          break;
        }
        grailedPage += 1;
      }
      if (hasMoreGrailed && nextGrailed.length >= batchSize) {
        grailedStopReason = 'batch_reached';
      } else if (hasMoreGrailed && grailedPagesFetched >= MAX_PAGES_PER_PROVIDER) {
        hasMoreGrailed = false;
        grailedStopReason = 'max_pages_reached';
      }
    }
    console.log('GRAILED_STOP_REASON', grailedStopReason);

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

