import type { FastifyInstance } from 'fastify';
import type { AnalyzeSearchBody } from '../types.js';
import {
  getSearchSession,
  newSearchSessionId,
  putSearchSession,
} from '../lib/search-session-store.js';
import { runAnalyzePipeline } from '../services/analyze-pipeline.js';

export async function searchSessionsRoute(app: FastifyInstance): Promise<void> {
  app.post<{ Body: AnalyzeSearchBody }>('/search-sessions', async (req, reply) => {
    const body = req.body as AnalyzeSearchBody;
    if (!body?.enabledProviders?.length) {
      return reply.code(400).send({ error: 'bad_request' });
    }
    const sessionId = newSearchSessionId();
    putSearchSession(sessionId, { pollStatus: 'queued' });
    void (async () => {
      try {
        await runAnalyzePipeline(body, {
          awaitSlowCompletion: true,
          fixedSessionId: sessionId,
        });
      } catch (e) {
        putSearchSession(sessionId, {
          pollStatus: 'failed',
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
      const job = getSearchSession(sessionId);
      if (!job) return reply.code(404).send({ error: 'not_found' });

      if (job.pollStatus === 'failed') {
        return reply.send({
          sessionId,
          status: 'failed',
          searchQuery: null,
          error: job.error ?? 'error',
          response: null,
          listings: [],
          providerStatuses: {},
        });
      }

      const res = job.response;
      return reply.send({
        sessionId,
        status: job.pollStatus,
        searchQuery: null,
        error: null,
        response: res ?? null,
        listings: res?.listings ?? [],
        providerStatuses: res?.providerStatuses ?? {},
      });
    }
  );
}
