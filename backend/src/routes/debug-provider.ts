import type { FastifyInstance } from 'fastify';
import type { MarketplaceListingDTO } from '../types.js';
import { getEbayDebugSnapshot } from '../lib/ebay-env.js';
import {
  gateDepopServer,
  gateEbayServer,
  gateGrailedServer,
  gateLeboncoinServer,
  gateVintedServer,
} from '../lib/provider-env.js';
import { ProviderScrapeError } from '../lib/provider-scrape-error.js';
import { PlaywrightChromiumMissingError } from '../lib/playwright-browser.js';
import {
  searchDepopListings,
  searchEbayListings,
  searchGrailedListings,
  searchLeboncoinListings,
  searchVintedListings,
} from '../services/marketplace-search.js';

type DebugReply = {
  provider: string;
  enabled: boolean;
  mode: string;
  status: string;
  count: number;
  sampleTitles: string[];
  error?: string;
  httpStatus?: number;
  durationMs: number;
  gateReason?: string;
  /** Diagnostic eBay (réponse debug). */
  query?: string;
  appIdPresent?: boolean;
  appIdSource?: string;
  globalId?: string;
  globalIdSource?: string;
};

function scrapeDebugOutcome(e: unknown): {
  httpStatus?: number;
  blocked: boolean;
  browserMissing: boolean;
} {
  if (e instanceof PlaywrightChromiumMissingError) {
    return { blocked: false, browserMissing: true };
  }
  if (e instanceof ProviderScrapeError) {
    return {
      httpStatus: e.httpStatus,
      blocked: !!(e.blocked403 || e.httpStatus === 403),
      browserMissing: false,
    };
  }
  return { blocked: false, browserMissing: false };
}

function vintedDebugMode(): string {
  const token = process.env.VINTED_ACCESS_TOKEN?.trim();
  return token ? 'bearer_api' : 'playwright_public';
}

/**
 * GET /debug-provider?provider=ebay|vinted|depop|grailed|leboncoin&q=test
 * Exemples : `?provider=depop&q=test`, `?provider=grailed&q=test`.
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
    const durationMs = (): number => Math.round(performance.now() - t0);

    async function vintedAnswer(): Promise<DebugReply> {
      const gate = gateVintedServer();
      const mode = vintedDebugMode();
      if (!gate.ready) {
        return {
          provider: 'vinted',
          enabled: false,
          mode,
          status: 'disabled_gate',
          count: 0,
          sampleTitles: [],
          error: gate.reason,
          durationMs: durationMs(),
          gateReason: gate.reason,
        };
      }
      try {
        const listings = await searchVintedListings([q]);
        return {
          provider: 'vinted',
          enabled: true,
          mode,
          status: listings.length ? 'success' : 'empty',
          count: listings.length,
          sampleTitles: sampleTitles(listings),
          durationMs: durationMs(),
        };
      } catch (e) {
        const err = e instanceof Error ? e.message : String(e);
        const o = scrapeDebugOutcome(e);
        return {
          provider: 'vinted',
          enabled: true,
          mode,
          status: o.browserMissing
            ? 'browser_missing'
            : o.blocked
              ? 'blocked_403'
              : 'error',
          count: 0,
          sampleTitles: [],
          error: err,
          httpStatus: o.httpStatus,
          durationMs: durationMs(),
        };
      }
    }

    async function ebayAnswer(): Promise<DebugReply> {
      const gate = gateEbayServer();
      const snap = getEbayDebugSnapshot();
      const mode = 'browse_api_oauth';
      if (!gate.ready) {
        return {
          provider: 'ebay',
          enabled: false,
          mode,
          status: 'disabled_gate',
          count: 0,
          sampleTitles: [],
          error: gate.reason,
          durationMs: durationMs(),
          gateReason: gate.reason,
        };
      }
      try {
        const listings = await searchEbayListings([q]);
        return {
          provider: 'ebay',
          enabled: true,
          mode,
          status: listings.length ? 'success' : 'empty',
          count: listings.length,
          sampleTitles: sampleTitles(listings),
          durationMs: durationMs(),
          ...ebaySnapPayload(snap, q),
        };
      } catch (e) {
        const err = e instanceof Error ? e.message : String(e);
        return {
          provider: 'ebay',
          enabled: true,
          mode,
          status: 'error',
          count: 0,
          sampleTitles: [],
          error: err,
          durationMs: durationMs(),
          ...ebaySnapPayload(snap, q),
        };
      }
    }

    async function scrapeProviderAnswer(
      name: 'grailed' | 'depop' | 'leboncoin',
      searcher: (queries: string[]) => Promise<MarketplaceListingDTO[]>
    ): Promise<DebugReply> {
      const gate =
        name === 'grailed'
          ? gateGrailedServer()
          : name === 'depop'
            ? gateDepopServer()
            : gateLeboncoinServer();
      const mode = 'playwright_scraper';

      if (!gate.ready) {
        return {
          provider: name,
          enabled: false,
          mode,
          status: 'disabled_gate',
          count: 0,
          sampleTitles: [],
          error: gate.reason,
          durationMs: durationMs(),
          gateReason: gate.reason,
        };
      }

      try {
        const listings = await searcher([q]);
        return {
          provider: name,
          enabled: true,
          mode,
          status: listings.length ? 'success' : 'empty',
          count: listings.length,
          sampleTitles: sampleTitles(listings),
          durationMs: durationMs(),
        };
      } catch (e) {
        const err = e instanceof Error ? e.message : String(e);
        const o = scrapeDebugOutcome(e);
        return {
          provider: name,
          enabled: true,
          mode,
          status: o.browserMissing
            ? 'browser_missing'
            : o.blocked
              ? 'blocked_403'
              : 'error',
          count: 0,
          sampleTitles: [],
          error: err,
          httpStatus: o.httpStatus,
          durationMs: durationMs(),
        };
      }
    }

    switch (provider) {
      case 'vinted':
        return reply.send(await vintedAnswer());
      case 'ebay':
        return reply.send(await ebayAnswer());

      case 'grailed':
        return reply.send(
          await scrapeProviderAnswer('grailed', searchGrailedListings)
        );
      case 'depop':
        return reply.send(
          await scrapeProviderAnswer('depop', searchDepopListings)
        );
      case 'leboncoin':
        return reply.send(
          await scrapeProviderAnswer('leboncoin', searchLeboncoinListings)
        );
      default:
        return reply.code(400).send({ error: 'unknown_provider', provider });
    }
  });
}

function sampleTitles(listings: MarketplaceListingDTO[]): string[] {
  return listings.slice(0, 10).map((l) => l.title);
}

function ebaySnapPayload(
  snap: ReturnType<typeof getEbayDebugSnapshot>,
  q: string
) {
  return {
    query: q,
    appIdPresent: snap.appIdPresent,
    appIdSource: snap.appIdSource,
    globalId: snap.globalId,
    globalIdSource: snap.globalIdSource,
  };
}
