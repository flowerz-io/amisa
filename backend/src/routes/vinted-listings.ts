import type { FastifyInstance } from 'fastify';
import { gateVintedServer } from '../lib/provider-env.js';
import { fetchVintedCatalogPage } from '../services/providers/vinted-api-search.js';

export async function vintedListingsRoute(app: FastifyInstance): Promise<void> {
  app.post<{
    Body: { searchText?: string; page?: number; offset?: number; limit?: number };
  }>('/vinted-listings', async (req, reply) => {
    const body = req.body ?? {};
    const searchText =
      typeof body.searchText === 'string' ? body.searchText.trim() : '';
    const pageRaw = body.page;
    const offsetRaw = body.offset;
    const perPage = 25;
    let page =
      typeof pageRaw === 'number' && Number.isFinite(pageRaw) && pageRaw >= 1
        ? Math.floor(pageRaw)
        : NaN;
    if (
      (!Number.isFinite(page) || page < 1) &&
      typeof offsetRaw === 'number' &&
      Number.isFinite(offsetRaw) &&
      offsetRaw >= 0
    ) {
      page = Math.floor(offsetRaw / perPage) + 1;
    }
    if (!Number.isFinite(page) || page < 1) {
      page = 1;
    }
    const effectiveOffset = (page - 1) * perPage;

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
      console.log('[PAGINATION_TRIGGER]', {
        route: 'vinted-listings',
        page,
        offset: effectiveOffset,
        limit: perPage,
      });
      const r = await fetchVintedCatalogPage(searchText, page);
      console.log('[VINTED_OFFSET]', {
        page,
        offset: effectiveOffset,
        limit: perPage,
        batch: r.listings.length,
        hasMore: r.hasMore,
      });
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
