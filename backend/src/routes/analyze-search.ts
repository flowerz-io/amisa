import type { FastifyInstance } from 'fastify';
import type { AnalyzeSearchBody } from '../types.js';
import { runAnalyzePipeline } from '../services/analyze-pipeline.js';

export async function analyzeSearchRoute(app: FastifyInstance): Promise<void> {
  app.post<{ Body: AnalyzeSearchBody }>('/analyze-search', async (req, reply) => {
    const body = req.body as AnalyzeSearchBody;
    if (!body.imageBase64 && !(body.textQuery && body.textQuery.trim())) {
      return reply.code(400).send({ error: 'bad_request', message: 'image or text required' });
    }
    try {
      const out = await runAnalyzePipeline(body);
      return reply.send(out);
    } catch (e) {
      req.log.error(e);
      return reply.code(500).send({ error: 'server_error' });
    }
  });
}
