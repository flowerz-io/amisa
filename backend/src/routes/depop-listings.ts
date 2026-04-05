import { FastifyInstance } from 'fastify';
import type { MarketplaceListingDTO } from '../api/types.js';
import { searchDepopByTextBrowser, type DepopSearchItem } from '../services/depop-browser-search.js';
import { DEPOP_MAX_PER_PAGE } from '../marketplace-limits.js';
import { isProviderEnabled } from '../providers-config.js';

type DepopListingsRequest = {
  searchText: string;
  page: number;
};

type DepopListingsResponse = {
  listings: MarketplaceListingDTO[];
  page: number;
  hasMore: boolean;
};

function depopItemsToListings(items: DepopSearchItem[]): MarketplaceListingDTO[] {
  return items.map((item, index) => {
    const id = item.providerItemId ?? item.listingUrl.match(/\/products\/([^/?#]+)/i)?.[1] ?? `depop-${index}`;
    return {
      id,
      source: 'Depop',
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

export async function depopListingsRoute(app: FastifyInstance) {
  app.post<{
    Body: DepopListingsRequest;
    Reply: DepopListingsResponse;
  }>('/depop-listings', async (request, reply) => {
    const body = request.body;
    if (!body?.searchText || typeof body.searchText !== 'string') {
      return reply.status(400).send({
        error: 'searchText is required',
      } as unknown as DepopListingsResponse);
    }

    const page = typeof body.page === 'number' && body.page >= 1 ? Math.floor(body.page) : 1;
    const searchText = body.searchText.trim();
    if (!searchText) {
      return reply.status(400).send({
        error: 'searchText must not be empty',
      } as unknown as DepopListingsResponse);
    }
    if (!isProviderEnabled('depop')) {
      console.log('[DEPOP_DISABLED] provider skipped');
      return reply.send({ listings: [], page, hasMore: false });
    }

    try {
      const result = await searchDepopByTextBrowser(searchText, { page, limit: DEPOP_MAX_PER_PAGE });
      const listings = depopItemsToListings(result.items);
      const hasMore = result.items.length >= DEPOP_MAX_PER_PAGE;
      return reply.send({
        listings,
        page,
        hasMore,
      });
    } catch (err) {
      request.log.error(err, 'depop-listings failed');
      console.error('[DEPOP_PROVIDER_ERROR]', err);
      return reply.status(502).send({
        error: 'depop_fetch_failed',
        message: 'Could not load listings',
      } as unknown as DepopListingsResponse);
    }
  });
}

