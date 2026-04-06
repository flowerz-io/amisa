/**
 * POST /search-sessions — lance une analyse en arrière-plan (réponse 202 + sessionId).
 * GET /search-sessions/:sessionId — état + résultat quand terminé.
 */

import type { FastifyInstance } from 'fastify';
import { randomUUID } from 'node:crypto';
import type { AnalyzeSearchRequest, AnalyzeSearchResponse } from '../api/types.js';
import {
  createSearchSession,
  getSearchSession,
  setSearchSessionCompleted,
  setSearchSessionFailed,
  updateSearchSession,
} from '../search-session-store.js';

export async function searchSessionsRoute(app: FastifyInstance) {
  app.post<{ Body: AnalyzeSearchRequest }>('/search-sessions', async (request, reply) => {
    const body = request.body;
    const sessionId = randomUUID();
    createSearchSession(sessionId);

    await reply.code(202).send({
      sessionId,
      status: 'queued',
      searchQuery: null as string | null,
    });

    void runSearchSessionInBackground(app, sessionId, body);
  });

  app.get<{ Params: { sessionId: string } }>('/search-sessions/:sessionId', async (request, reply) => {
    const { sessionId } = request.params;
    const record = getSearchSession(sessionId);
    if (!record) {
      return reply.status(404).send({ error: 'session_not_found', sessionId });
    }

    const primaryQuery =
      record.result?.generatedQueries?.[0] ??
      record.result?.rankingContext?.primaryQuery ??
      record.searchQuery ??
      '';

    if (record.status === 'completed' && record.result) {
      return reply.send({
        sessionId,
        status: 'completed',
        searchQuery: primaryQuery,
        response: record.result,
      });
    }

    if (record.status === 'failed') {
      return reply.send({
        sessionId,
        status: 'failed',
        searchQuery: record.searchQuery ?? null,
        error: record.errorMessage ?? 'search_failed',
        errorPayload: record.errorPayload,
      });
    }

    return reply.send({
      sessionId,
      status: record.status,
      searchQuery: primaryQuery || null,
    });
  });
}

async function runSearchSessionInBackground(
  app: FastifyInstance,
  sessionId: string,
  body: AnalyzeSearchRequest
): Promise<void> {
  updateSearchSession(sessionId, { status: 'analyzing' });
  try {
    updateSearchSession(sessionId, { status: 'searching' });
    const res = await app.inject({
      method: 'POST',
      url: '/analyze-search',
      headers: { 'content-type': 'application/json' },
      payload: body,
    });

    const payloadText = res.payload?.toString?.() ?? String(res.payload ?? '');
    if (res.statusCode !== 200) {
      let errBody: unknown = payloadText;
      try {
        errBody = JSON.parse(payloadText);
      } catch {
        /* ignore */
      }
      setSearchSessionFailed(sessionId, `http_${res.statusCode}`, errBody);
      return;
    }

    const data = JSON.parse(payloadText) as AnalyzeSearchResponse;
    const searchQuery =
      data.generatedQueries?.[0]?.trim() ||
      data.rankingContext?.primaryQuery?.trim() ||
      '';
    setSearchSessionCompleted(sessionId, data, searchQuery);
  } catch (e) {
    requestLogError(app, e);
    setSearchSessionFailed(sessionId, e instanceof Error ? e.message : String(e));
  }
}

function requestLogError(app: FastifyInstance, err: unknown): void {
  try {
    app.log.error(err);
  } catch {
    console.error('[SEARCH_SESSION_BG]', err);
  }
}
