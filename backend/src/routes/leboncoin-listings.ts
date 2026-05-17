import type { FastifyInstance } from 'fastify';

export async function leBonCoinListingsRoute(app: FastifyInstance): Promise<void> {
  app.post('/leboncoin-listings', async (_req, reply) => {
    return reply.send({ listings: [], hasMore: false });
  });
}
