import type { FastifyInstance } from 'fastify';
import { randomUUID } from 'node:crypto';
import type { AnalyzeSearchBody } from '../types.js';
import { runAnalyzePipeline } from '../services/analyze-pipeline.js';

type Job = {
  status: 'queued' | 'running' | 'completed' | 'failed';
  response?: unknown;
  error?: string;
};

const jobs = new Map<string, Job>();

export async function searchSessionsRoute(app: FastifyInstance): Promise<void> {
  app.post<{ Body: AnalyzeSearchBody }>('/search-sessions', async (req, reply) => {
    const body = req.body as AnalyzeSearchBody;
    if (!body?.enabledProviders?.length) {
      return reply.code(400).send({ error: 'bad_request' });
    }
    const sessionId = randomUUID();
    jobs.set(sessionId, { status: 'queued' });
    void (async () => {
      const j = jobs.get(sessionId);
      if (!j) return;
      j.status = 'running';
      try {
        const response = await runAnalyzePipeline(body);
        jobs.set(sessionId, { status: 'completed', response });
      } catch (e) {
        jobs.set(sessionId, {
          status: 'failed',
          error: e instanceof Error ? e.message : String(e),
        });
      }
    })();
    return reply.code(202).send({
      sessionId,
      status: 'queued',
      searchQuery: null,
    });
  });

  app.get<{ Params: { sessionId: string } }>(
    '/search-sessions/:sessionId',
    async (req, reply) => {
      const { sessionId } = req.params;
      const job = jobs.get(sessionId);
      if (!job) return reply.code(404).send({ error: 'not_found' });
      if (job.status === 'completed') {
        return reply.send({
          sessionId,
          status: 'completed',
          searchQuery: null,
          error: null,
          response: job.response,
        });
      }
      if (job.status === 'failed') {
        return reply.send({
          sessionId,
          status: 'failed',
          searchQuery: null,
          error: job.error ?? 'error',
          response: null,
        });
      }
      return reply.send({
        sessionId,
        status: 'running',
        searchQuery: null,
        error: null,
        response: null,
      });
    }
  );
}
