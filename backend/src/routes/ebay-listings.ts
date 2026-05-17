import type { FastifyInstance } from 'fastify';

export async function ebayListingsRoute(app: FastifyInstance): Promise<void> {
  app.post('/ebay-listings', async (_req, reply) => {
    return reply.send({ listings: [], hasMore: false });
  });
}
