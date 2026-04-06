import { FastifyInstance } from 'fastify';
import type { EbayListingsRequest, EbayListingsResponse, MarketplaceListingDTO } from '../api/types.js';
import { searchEbayByText, type EbaySearchItem } from '../services/ebay-api-search.js';
import { EBAY_MAX_PER_PAGE } from '../marketplace-limits.js';
import { isProviderEnabled } from '../providers-config.js';

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
      brand: item.brand,
      ...(item.size ? { size: item.size } : {}),
      ...(item.condition ? { condition: item.condition } : {}),
      ...(item.publishedAtRelative ? { publishedAtRelative: item.publishedAtRelative } : {}),
    };
  });
}

export async function ebayListingsRoute(app: FastifyInstance) {
  app.post<{
    Body: EbayListingsRequest;
    Reply: EbayListingsResponse;
  }>('/ebay-listings', async (request, reply) => {
    const body = request.body;
    if (!body?.searchText || typeof body.searchText !== 'string') {
      return reply.status(400).send({
        error: 'searchText is required',
      } as unknown as EbayListingsResponse);
    }
    const page = typeof body.page === 'number' && body.page >= 1 ? Math.floor(body.page) : 1;
    const searchText = body.searchText.trim();
    if (!searchText) {
      return reply.status(400).send({
        error: 'searchText must not be empty',
      } as unknown as EbayListingsResponse);
    }
    if (!isProviderEnabled('ebay')) {
      console.log('[EBAY_DISABLED] provider skipped');
      return reply.send({ listings: [], page, hasMore: false });
    }

    try {
      const result = await searchEbayByText(searchText, { page });
      const listings = ebayItemsToListings(result.items);
      const isBlockedOrUnavailable =
        result.stopReason === 'api_error' || result.stopReason === 'credentials_missing';
      const limit = EBAY_MAX_PER_PAGE;
      const loadedThrough = (page - 1) * limit + result.items.length;
      const hasMore =
        !isBlockedOrUnavailable &&
        result.items.length > 0 &&
        (result.totalCount === undefined
          ? result.items.length >= limit
          : loadedThrough < result.totalCount);
      if (result.stopReason && result.stopReason !== 'ok') {
        console.log('[EBAY_STOP_REASON]', result.stopReason);
      }
      return reply.send({
        listings,
        page,
        hasMore,
        ...(result.totalCount !== undefined ? { totalCount: result.totalCount } : {}),
      });
    } catch (err) {
      request.log.error(err, 'ebay-listings failed');
      console.error('[EBAY_PROVIDER_ERROR]', err);
      return reply.status(502).send({
        error: 'ebay_fetch_failed',
        message: 'Could not load listings',
      } as unknown as EbayListingsResponse);
    }
  });
}

