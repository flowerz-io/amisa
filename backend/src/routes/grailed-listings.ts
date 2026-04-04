import { FastifyInstance } from 'fastify';
import type { GrailedListingsRequest, GrailedListingsResponse } from '../api/types.js';
import { searchGrailedByText, type GrailedSearchItem } from '../services/grailed-text-search.js';
import type { MarketplaceListingDTO } from '../api/types.js';
import { GRAILED_MAX_PER_PAGE } from '../marketplace-limits.js';

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

export async function grailedListingsRoute(app: FastifyInstance) {
  app.post<{
    Body: GrailedListingsRequest;
    Reply: GrailedListingsResponse;
  }>('/grailed-listings', async (request, reply) => {
    const body = request.body;

    if (!body?.searchText || typeof body.searchText !== 'string') {
      return reply.status(400).send({
        error: 'searchText is required',
      } as unknown as GrailedListingsResponse);
    }

    const page = typeof body.page === 'number' && body.page >= 1 ? Math.floor(body.page) : 1;
    const searchText = body.searchText.trim();

    if (!searchText) {
      return reply.status(400).send({
        error: 'searchText must not be empty',
      } as unknown as GrailedListingsResponse);
    }

    // eslint-disable-next-line no-console -- traçage
    console.log('[GRAILED_LISTINGS_PAGE]', { page, searchText: searchText.slice(0, 80) });

    try {
      const items = await searchGrailedByText(searchText, { page });
      const listings = grailedItemsToListings(items);
      const hasMore = items.length >= GRAILED_MAX_PER_PAGE;

      const response: GrailedListingsResponse = {
        listings,
        page,
        hasMore,
      };

      return reply.send(response);
    } catch (err) {
      request.log.error(err, 'grailed-listings failed');
      // eslint-disable-next-line no-console -- diagnostic
      console.error('[GRAILED_LISTINGS_ROUTE_FAILED]', err);
      return reply.status(502).send({
        error: 'grailed_fetch_failed',
        message: 'Could not load listings',
      } as unknown as GrailedListingsResponse);
    }
  });
}
