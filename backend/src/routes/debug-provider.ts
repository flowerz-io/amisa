import type { FastifyInstance } from 'fastify';
import type { MarketplaceListingDTO } from '../types.js';
import { getEbayDebugSnapshot } from '../lib/ebay-env.js';
import {
  gateDepopServer,
  gateGrailedServer,
  gateLeboncoinServer,
  gateVintedServer,
} from '../lib/provider-env.js';
import {
  searchDepopListings,
  searchEbayListings,
  searchGrailedListings,
  searchLeboncoinListings,
  searchVintedListings,
} from '../services/marketplace-search.js';

/**
 * GET /debug-provider?provider=ebay&q=black+loafers
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

    if (provider === 'vinted') {
      const gate = gateVintedServer();
      if (!gate.ready) {
        return reply.send({
          provider: 'vinted',
          enabled: false,
          mode: 'scraper',
          tokenRequired: false,
          gateReason: gate.reason,
          count: 0,
          sampleTitles: [] as string[],
          durationMs: Math.round(performance.now() - t0),
        });
      }
      try {
        const listings = await searchVintedListings([q]);
        const durationMs = Math.round(performance.now() - t0);
        return reply.send({
          provider: 'vinted',
          enabled: true,
          mode: 'scraper',
          tokenRequired: false,
          count: listings.length,
          sampleTitles: listings.slice(0, 10).map((l) => l.title),
          durationMs,
        });
      } catch (e) {
        const durationMs = Math.round(performance.now() - t0);
        const err = e instanceof Error ? e.message : String(e);
        return reply.send({
          provider: 'vinted',
          enabled: true,
          mode: 'scraper',
          tokenRequired: false,
          count: 0,
          sampleTitles: [] as string[],
          error: err,
          durationMs,
        });
      }
    }

    if (provider === 'ebay') {
      const snap = getEbayDebugSnapshot();
      try {
        const listings = await searchEbayListings([q]);
        const durationMs = Math.round(performance.now() - t0);
        return reply.send({
          provider: 'ebay',
          query: q,
          appIdPresent: snap.appIdPresent,
          appIdSource: snap.appIdSource,
          globalId: snap.globalId,
          globalIdSource: snap.globalIdSource,
          status: 'ok' as const,
          count: listings.length,
          sampleTitles: listings.slice(0, 10).map((l) => l.title),
          durationMs,
        });
      } catch (e) {
        const rawError = e instanceof Error ? e.message : String(e);
        const durationMs = Math.round(performance.now() - t0);
        return reply.send({
          provider: 'ebay',
          query: q,
          appIdPresent: snap.appIdPresent,
          appIdSource: snap.appIdSource,
          globalId: snap.globalId,
          globalIdSource: snap.globalIdSource,
          status: 'error' as const,
          count: 0,
          sampleTitles: [] as string[],
          durationMs,
          rawError,
        });
      }
    }

    let gate:
      | ReturnType<typeof gateGrailedServer>
      | ReturnType<typeof gateDepopServer>
      | ReturnType<typeof gateLeboncoinServer>;
    if (provider === 'grailed') gate = gateGrailedServer();
    else if (provider === 'depop') gate = gateDepopServer();
    else if (provider === 'leboncoin') gate = gateLeboncoinServer();
    else {
      return reply.code(400).send({ error: 'unknown_provider', provider });
    }

    if (!gate.ready) {
      return reply.send({
        provider,
        enabled: false,
        mode: 'scraper',
        tokenRequired: false,
        gateReason: gate.reason,
        count: 0,
        sampleTitles: [] as string[],
        durationMs: Math.round(performance.now() - t0),
      });
    }

    try {
      let listings: MarketplaceListingDTO[];
      switch (provider) {
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
        enabled: true,
        mode: 'scraper',
        tokenRequired: false,
        query: q,
        status: 'ok' as const,
        durationMs,
        count: listings.length,
        sampleTitles: listings.slice(0, 10).map((l) => l.title),
      });
    } catch (e) {
      const durationMs = Math.round(performance.now() - t0);
      const rawError = e instanceof Error ? e.message : String(e);
      return reply.send({
        provider,
        enabled: true,
        mode: 'scraper',
        tokenRequired: false,
        query: q,
        status: 'error' as const,
        durationMs,
        count: 0,
        sampleTitles: [] as string[],
        error: rawError,
      });
    }
  });
}
