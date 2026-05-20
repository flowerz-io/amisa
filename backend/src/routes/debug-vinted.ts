import type { FastifyInstance } from 'fastify';
import { gateVintedServer } from '../lib/provider-env.js';
import { fetchVintedCatalogPage } from '../services/providers/vinted-api-search.js';

/**
 * GET /debug-vinted?q=robe+noire
 * Désactiver : DEBUG_PROVIDER_ROUTE=0
 */
export async function debugVintedRoute(app: FastifyInstance): Promise<void> {
  app.get<{ Querystring: { q?: string } }>('/debug-vinted', async (req, reply) => {
    if (process.env.DEBUG_PROVIDER_ROUTE === '0') {
      return reply.code(404).send({ error: 'debug route disabled' });
    }

    const q = (req.query.q ?? 'Adidas Samba').trim();
    const gate = gateVintedServer();
    if (!gate.ready) {
      return reply.send({
        ok: false,
        enabled: false,
        reason: gate.reason,
        count: 0,
        hasMore: false,
        sampleTitles: [] as string[],
      });
    }

    try {
      const r = await fetchVintedCatalogPage(q, 1);
      return reply.send({
        ok: true,
        enabled: true,
        count: r.listings.length,
        hasMore: r.hasMore,
        sampleTitles: r.listings.slice(0, 5).map((x) => x.title),
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return reply.send({
        ok: false,
        enabled: true,
        error: msg.slice(0, 500),
        count: 0,
        hasMore: false,
        sampleTitles: [] as string[],
      });
    }
  });
}
