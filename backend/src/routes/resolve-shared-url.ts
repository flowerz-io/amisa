import type { FastifyInstance } from 'fastify';

/** Stub minimal — à remplacer par la résolution URL réelle (Instagram, etc.). */
export async function resolveSharedUrlRoute(app: FastifyInstance): Promise<void> {
  app.post('/resolve-shared-url', async (_req, reply) => {
    return reply.code(501).send({ error: 'not_implemented' });
  });
}
