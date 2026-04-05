import { FastifyInstance } from 'fastify';
import type { LeBonCoinListingsRequest, LeBonCoinListingsResponse } from '../api/types.js';
import type { MarketplaceListingDTO } from '../api/types.js';
import { searchLeBonCoinByTextBrowser, type LeBonCoinSearchItem } from '../services/leboncoin-browser-search.js';
import { LEBONCOIN_MAX_PER_PAGE } from '../marketplace-limits.js';
import { isProviderEnabled } from '../providers-config.js';

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

export async function leBonCoinListingsRoute(app: FastifyInstance) {
  app.post<{
    Body: LeBonCoinListingsRequest;
    Reply: LeBonCoinListingsResponse;
  }>('/leboncoin-listings', async (request, reply) => {
    const body = request.body;
    if (!body?.searchText || typeof body.searchText !== 'string') {
      return reply.status(400).send({
        error: 'searchText is required',
      } as unknown as LeBonCoinListingsResponse);
    }

    const page = typeof body.page === 'number' && body.page >= 1 ? Math.floor(body.page) : 1;
    const searchText = body.searchText.trim();
    if (!searchText) {
      return reply.status(400).send({
        error: 'searchText must not be empty',
      } as unknown as LeBonCoinListingsResponse);
    }

    console.log('[LEBONCOIN_LISTINGS_PAGE]', { page, searchText: searchText.slice(0, 80) });

    if (!isProviderEnabled('leboncoin')) {
      console.log('[LEBONCOIN_DISABLED] anti-bot challenge detected, provider skipped');
      return reply.send({
        listings: [],
        page,
        hasMore: false,
      });
    }

    try {
      const result = await searchLeBonCoinByTextBrowser(searchText, { page });
      const listings = leBonCoinItemsToListings(result.items);
      const hasMore = result.items.length >= LEBONCOIN_MAX_PER_PAGE;
      return reply.send({
        listings,
        page,
        hasMore,
        ...(result.totalCount !== undefined ? { totalCount: result.totalCount } : {}),
      });
    } catch (err) {
      request.log.error(err, 'leboncoin-listings failed');
      console.error('[LEBONCOIN_LISTINGS_ROUTE_FAILED]', err);
      return reply.status(502).send({
        error: 'leboncoin_fetch_failed',
        message: 'Could not load listings',
      } as unknown as LeBonCoinListingsResponse);
    }
  });
}

