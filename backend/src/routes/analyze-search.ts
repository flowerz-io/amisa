import type { FastifyInstance } from 'fastify';
import type { AnalyzeSearchBody } from '../types.js';
import { runAnalyzePipeline } from '../services/analyze-pipeline.js';
import { GeminiVisionError } from '../services/vision/gemini-errors.js';

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
      if (e instanceof GeminiVisionError) {
        req.log.warn({ code: e.code, httpStatus: e.httpStatus }, e.message);
        const status = e.httpStatus ?? (e.code === 'gemini_quota_exceeded' ? 429 : 503);
        return reply.code(status).send({
          error: e.code,
          message: e.message,
        });
      }
      req.log.error(e);
      return reply.code(500).send({ error: 'server_error', message: 'Internal server error' });
    }
  });
}
