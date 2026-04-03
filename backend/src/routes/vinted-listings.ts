import { FastifyInstance } from 'fastify';
import type { VintedListingsRequest, VintedListingsResponse } from '../api/types.js';
import { searchVintedByText, type VintedSearchItem } from '../services/vinted-text-search.js';
import type { MarketplaceListingDTO } from '../api/types.js';

const PER_PAGE = 10;

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

export async function vintedListingsRoute(app: FastifyInstance) {
  app.post<{
    Body: VintedListingsRequest;
    Reply: VintedListingsResponse;
  }>('/vinted-listings', async (request, reply) => {
    const body = request.body;

    if (!body?.searchText || typeof body.searchText !== 'string') {
      return reply.status(400).send({
        error: 'searchText is required',
      } as unknown as VintedListingsResponse);
    }

    const page = typeof body.page === 'number' && body.page >= 1 ? Math.floor(body.page) : 1;
    const searchText = body.searchText.trim();

    if (!searchText) {
      return reply.status(400).send({
        error: 'searchText must not be empty',
      } as unknown as VintedListingsResponse);
    }

    // eslint-disable-next-line no-console -- traçage
    console.log('[VINTED_LISTINGS_PAGE]', { page, searchText: searchText.slice(0, 80) });

    try {
      const items = await searchVintedByText(searchText, { page });
      const listings = vintedItemsToListings(items);
      const hasMoreHint = items.length >= PER_PAGE;

      const response: VintedListingsResponse = {
        listings,
        page,
        hasMoreHint,
      };

      return reply.send(response);
    } catch (err) {
      request.log.error(err, 'vinted-listings failed');
      return reply.status(502).send({
        error: 'vinted_fetch_failed',
        message: 'Could not load listings',
      } as unknown as VintedListingsResponse);
    }
  });
}
