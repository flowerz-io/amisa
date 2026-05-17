import type { FastifyInstance } from 'fastify';

export async function searchMoreRoute(app: FastifyInstance): Promise<void> {
  app.post('/search-more', async (req, reply) => {
    const body = req.body as {
      pagination: unknown;
    };
    return reply.send({
      listings: [],
      vintedListings: [],
      grailedListings: [],
      ebayListings: [],
      leboncoinListings: [],
      depopListings: [],
      pagination: body?.pagination,
      hasMoreVinted: false,
      hasMoreGrailed: false,
      hasMoreEbay: false,
      hasMoreLeboncoin: false,
      hasMoreDepop: false,
      providerAvailability: null,
      providerCounts: null,
    });
  });
}
