import type { FastifyInstance } from 'fastify';

export async function grailedListingsRoute(app: FastifyInstance): Promise<void> {
  app.post('/grailed-listings', async (_req, reply) => {
    return reply.send({ listings: [], hasMore: false });
  });
}
