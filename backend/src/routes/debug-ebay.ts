import type { FastifyInstance } from 'fastify';
import { runEbayDebugSearch } from '../services/providers/ebay-browse-search.js';

/**
 * GET /debug-ebay?q=adidas+samba
 * Désactiver : DEBUG_PROVIDER_ROUTE=0 (même interrupteur que /debug-provider)
 */
export async function debugEbayRoute(app: FastifyInstance): Promise<void> {
  app.get<{
    Querystring: { q?: string };
  }>('/debug-ebay', async (req, reply) => {
    if (process.env.DEBUG_PROVIDER_ROUTE === '0') {
      return reply.code(404).send({ error: 'debug route disabled' });
    }

    const q = (req.query.q ?? 'adidas samba').trim() || 'adidas samba';

    const t0 = performance.now();
    const payload = await runEbayDebugSearch(q);

    return reply.send({
      ...payload,
      durationMs: Math.round(performance.now() - t0),
    });
  });
}
