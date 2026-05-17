import type { FastifyInstance } from 'fastify';
import type { MarketplaceListingDTO } from '../types.js';
import {
  searchDepopListings,
  searchEbayListings,
  searchGrailedListings,
  searchLeboncoinListings,
  searchVintedListings,
} from '../services/marketplace-search.js';

/**
 * GET /debug-provider?provider=ebay&q=Adidas%20Samba
 * Désactiver : DEBUG_PROVIDER_ROUTE=0
 */
export async function debugProviderRoute(app: FastifyInstance): Promise<void> {
  app.get<{
    Querystring: { provider?: string; q?: string };
  }>('/debug-provider', async (req, reply) => {
    if (process.env.DEBUG_PROVIDER_ROUTE === '0') {
      return reply.code(404).send({ error: 'debug route disabled' });
    }

    const provider = (req.query.provider ?? 'ebay').toLowerCase().trim();
    const q = (req.query.q ?? 'Adidas Samba').trim();
    const t0 = performance.now();

    try {
      let listings: MarketplaceListingDTO[];
      switch (provider) {
        case 'vinted':
          listings = await searchVintedListings([q]);
          break;
        case 'ebay':
          listings = await searchEbayListings([q]);
          break;
        case 'grailed':
          listings = await searchGrailedListings([q]);
          break;
        case 'depop':
          listings = await searchDepopListings([q]);
          break;
        case 'leboncoin':
          listings = await searchLeboncoinListings([q]);
          break;
        default:
          return reply.code(400).send({ error: 'unknown_provider', provider });
      }

      const durationMs = Math.round(performance.now() - t0);
      return reply.send({
        provider,
        query: q,
        durationMs,
        count: listings.length,
        sampleTitles: listings.slice(0, 10).map((l) => l.title),
      });
    } catch (e) {
      const durationMs = Math.round(performance.now() - t0);
      return reply.code(500).send({
        provider,
        query: q,
        durationMs,
        count: 0,
        sampleTitles: [] as string[],
        error: e instanceof Error ? e.message : String(e),
      });
    }
  });
}
