import type { FastifyInstance } from 'fastify';

export async function depopListingsRoute(app: FastifyInstance): Promise<void> {
  app.post('/depop-listings', async (_req, reply) => {
    return reply.send({ listings: [], hasMore: false });
  });
}
