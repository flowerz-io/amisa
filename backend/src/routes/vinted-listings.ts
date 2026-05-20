import type { FastifyInstance } from 'fastify';
import { gateVintedServer } from '../lib/provider-env.js';
import { fetchVintedCatalogPage } from '../services/providers/vinted-api-search.js';

export async function vintedListingsRoute(app: FastifyInstance): Promise<void> {
  app.post<{
    Body: { searchText?: string; page?: number };
  }>('/vinted-listings', async (req, reply) => {
    const body = req.body ?? {};
    const searchText =
      typeof body.searchText === 'string' ? body.searchText.trim() : '';
    const pageRaw = body.page;
    const page =
      typeof pageRaw === 'number' && Number.isFinite(pageRaw) && pageRaw >= 1
        ? Math.floor(pageRaw)
        : 1;

    if (!searchText) {
      return reply
        .code(400)
        .send({ error: 'bad_request', message: 'searchText required' });
    }

    const gate = gateVintedServer();
    if (!gate.ready) {
      return reply.code(502).send({
        error: 'vinted_disabled',
        message: gate.reason,
      });
    }

    try {
      const r = await fetchVintedCatalogPage(searchText, page);
      return reply.send({
        listings: r.listings,
        page,
        hasMore: r.hasMore,
      });
    } catch (e) {
      req.log.error(e);
      return reply.code(502).send({ error: 'vinted_fetch_failed' });
    }
  });
}
