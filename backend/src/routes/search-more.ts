import { FastifyInstance } from 'fastify';
import type {
  MarketplaceListingDTO,
  SearchMoreRequest,
  SearchMoreResponse,
} from '../api/types.js';
import { searchVintedByText, type VintedSearchItem } from '../services/vinted-text-search.js';
import { searchGrailedByTextBrowser } from '../services/grailed-browser-search.js';
import { searchLeBonCoinByTextBrowser, type LeBonCoinSearchItem } from '../services/leboncoin-browser-search.js';
import { searchEbayByText, type EbaySearchItem } from '../services/ebay-text-search.js';
import { rankAcrossSources } from '../services/marketplace-ranking.js';
import {
  EBAY_MAX_PER_PAGE,
  GRAILED_MAX_PER_PAGE,
  LEBONCOIN_MAX_PER_PAGE,
  MAX_PAGES_PER_PROVIDER,
  NEXT_BATCH_PER_PROVIDER,
  VINTED_MAX_PER_PAGE,
} from '../marketplace-limits.js';
import { isProviderEnabled } from '../providers-config.js';

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
      ebayNextPage: body.pagination.ebay?.nextPage,
      leboncoinNextPage: body.pagination.leboncoin?.nextPage,
      hasMoreVinted: body.pagination.vinted.hasMore,
      hasMoreGrailed: body.pagination.grailed.hasMore,
      hasMoreEbay: body.pagination.ebay?.hasMore,
      hasMoreLeboncoin: body.pagination.leboncoin?.hasMore,
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

    const nextEbay: MarketplaceListingDTO[] = [];
    const ebayState = body.pagination.ebay;
    let ebayPage = Math.max(1, ebayState?.nextPage ?? 2);
    let hasMoreEbay = isProviderEnabled('ebay') && (ebayState?.hasMore ?? true);
    let ebayStopReason = ebayState ? 'already_exhausted' : 'missing_pagination_state_assumed_has_more';
    let ebayPagesFetched = 0;
    if (!isProviderEnabled('ebay')) {
      console.log('[EBAY_DISABLED] provider skipped');
      hasMoreEbay = false;
      ebayStopReason = 'provider_disabled';
    }
    if (hasMoreEbay) {
      while (nextEbay.length < batchSize && ebayPagesFetched < MAX_PAGES_PER_PROVIDER) {
        const remaining = batchSize - nextEbay.length;
        const pageLimit = Math.max(1, Math.min(EBAY_MAX_PER_PAGE, remaining));
        let pageItems: EbaySearchItem[] = [];
        try {
          const result = await searchEbayByText(query, { page: ebayPage, limit: pageLimit });
          pageItems = result.items;
        } catch (err) {
          hasMoreEbay = false;
          ebayStopReason = 'provider_error';
          request.log.error(err, 'eBay pagination failed');
          console.error('[EBAY_PROVIDER_ERROR]', err);
          break;
        }
        const mapped = ebayItemsToListings(pageItems);
        const added = dedupePush(nextEbay, mapped);
        console.log('[CURRENT_EBAY_PAGE]', ebayPage);
        ebayPagesFetched += 1;

        if (pageItems.length === 0) {
          hasMoreEbay = false;
          ebayStopReason = 'page_empty';
          break;
        }
        if (added === 0) {
          hasMoreEbay = false;
          ebayStopReason = 'no_new_unique_on_page';
          break;
        }
        if (pageItems.length < pageLimit) {
          hasMoreEbay = false;
          ebayStopReason = 'provider_exhausted';
          break;
        }
        ebayPage += 1;
      }
      if (hasMoreEbay && nextEbay.length >= batchSize) {
        ebayStopReason = 'batch_reached';
      } else if (hasMoreEbay && ebayPagesFetched >= MAX_PAGES_PER_PROVIDER) {
        hasMoreEbay = false;
        ebayStopReason = 'max_pages_reached';
      }
    }
    console.log('[EBAY_STOP_REASON]', ebayStopReason);

    const nextLeboncoin: MarketplaceListingDTO[] = [];
    const leboncoinState = body.pagination.leboncoin;
    let leboncoinPage = Math.max(1, leboncoinState?.nextPage ?? 2);
    let hasMoreLeboncoin = (leboncoinState?.hasMore ?? false) && isProviderEnabled('leboncoin');
    let leboncoinStopReason = leboncoinState ? 'already_exhausted' : 'missing_pagination_state';
    let leboncoinPagesFetched = 0;
    if (!isProviderEnabled('leboncoin')) {
      console.log('[LEBONCOIN_DISABLED] anti-bot challenge detected, provider skipped');
      hasMoreLeboncoin = false;
      leboncoinStopReason = 'provider_disabled';
    }
    if (hasMoreLeboncoin) {
      while (nextLeboncoin.length < batchSize && leboncoinPagesFetched < MAX_PAGES_PER_PROVIDER) {
        const remaining = batchSize - nextLeboncoin.length;
        const pageLimit = Math.max(1, Math.min(LEBONCOIN_MAX_PER_PAGE, remaining));
        let pageItems: LeBonCoinSearchItem[] = [];
        try {
          const result = await searchLeBonCoinByTextBrowser(query, { page: leboncoinPage, limit: pageLimit });
          pageItems = result.items;
        } catch (err) {
          hasMoreLeboncoin = false;
          leboncoinStopReason = 'provider_error';
          request.log.error(err, 'Le Bon Coin pagination failed');
          console.log('[LEBONCOIN_ERROR]', err instanceof Error ? err.message : String(err));
          break;
        }
        const mapped = leBonCoinItemsToListings(pageItems);
        const added = dedupePush(nextLeboncoin, mapped);
        console.log('CURRENT_LEBONCOIN_PAGE', leboncoinPage);
        leboncoinPagesFetched += 1;

        if (pageItems.length === 0) {
          hasMoreLeboncoin = false;
          leboncoinStopReason = 'page_empty';
          break;
        }
        if (added === 0) {
          hasMoreLeboncoin = false;
          leboncoinStopReason = 'no_new_unique_on_page';
          break;
        }
        if (pageItems.length < pageLimit) {
          hasMoreLeboncoin = false;
          leboncoinStopReason = 'provider_exhausted';
          break;
        }
        leboncoinPage += 1;
      }
      if (hasMoreLeboncoin && nextLeboncoin.length >= batchSize) {
        leboncoinStopReason = 'batch_reached';
      } else if (hasMoreLeboncoin && leboncoinPagesFetched >= MAX_PAGES_PER_PROVIDER) {
        hasMoreLeboncoin = false;
        leboncoinStopReason = 'max_pages_reached';
      }
    }
    console.log('LEBONCOIN_STOP_REASON', leboncoinStopReason);

    console.log('VINTED_NEXT_BATCH_COUNT', nextVinted.length);
    console.log('GRAILED_NEXT_BATCH_COUNT', nextGrailed.length);
    console.log('[EBAY_NEXT_BATCH_COUNT]', nextEbay.length);
    console.log('LEBONCOIN_NEXT_BATCH_COUNT', nextLeboncoin.length);

    const merged = rankAcrossSources([...nextVinted, ...nextGrailed, ...nextEbay, ...nextLeboncoin], body.rankingContext);
    console.log('MERGED_NEXT_BATCH_COUNT', merged.length);
    console.log('TOTAL_LOADED_VINTED', body.pagination.vinted.loadedCount + nextVinted.length);
    console.log('TOTAL_LOADED_GRAILED', body.pagination.grailed.loadedCount + nextGrailed.length);
    console.log('[TOTAL_LOADED_EBAY]', (body.pagination.ebay?.loadedCount ?? 0) + nextEbay.length);
    console.log(
      'TOTAL_LOADED_LEBONCOIN',
      (body.pagination.leboncoin?.loadedCount ?? 0) + nextLeboncoin.length
    );
    console.log('HAS_MORE_VINTED', hasMoreVinted);
    console.log('HAS_MORE_GRAILED', hasMoreGrailed);
    console.log('[HAS_MORE_EBAY]', hasMoreEbay);
    console.log('HAS_MORE_LEBONCOIN', hasMoreLeboncoin);
    console.log('NEXT_RESPONSE_TIME_MS', Date.now() - startedAt);

    return reply.send({
      listings: merged,
      vintedListings: nextVinted,
      grailedListings: nextGrailed,
      ebayListings: nextEbay,
      leboncoinListings: nextLeboncoin,
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
        ebay: {
          nextPage: ebayPage,
          hasMore: hasMoreEbay,
          loadedCount: (body.pagination.ebay?.loadedCount ?? 0) + nextEbay.length,
        },
        leboncoin: {
          nextPage: leboncoinPage,
          hasMore: hasMoreLeboncoin,
          loadedCount: (body.pagination.leboncoin?.loadedCount ?? 0) + nextLeboncoin.length,
        },
      },
      hasMoreVinted,
      hasMoreGrailed,
      hasMoreEbay,
      hasMoreLeboncoin,
    });
  });
}

