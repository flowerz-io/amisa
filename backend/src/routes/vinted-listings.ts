import type { FastifyInstance } from 'fastify';

export async function vintedListingsRoute(app: FastifyInstance): Promise<void> {
  app.post('/vinted-listings', async (_req, reply) => {
    return reply.send({ listings: [], page: 1, hasMore: false });
  });
}
