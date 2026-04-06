/**
 * Sessions de recherche async (mémoire process — source de vérité métier = résultats Railway).
 * Pour la prod multi-instances, remplacer par Redis / DB.
 */

import type { AnalyzeSearchResponse } from './api/types.js';

export type SearchSessionStatus =
  | 'queued'
  | 'analyzing'
  | 'searching'
  | 'completed'
  | 'failed';

export interface SearchSessionRecord {
  status: SearchSessionStatus;
  createdAt: number;
  searchQuery?: string;
  result?: AnalyzeSearchResponse;
  httpStatus?: number;
  errorPayload?: unknown;
  errorMessage?: string;
}

const sessions = new Map<string, SearchSessionRecord>();

export function createSearchSession(sessionId: string): void {
  sessions.set(sessionId, { status: 'queued', createdAt: Date.now() });
}

export function updateSearchSession(
  sessionId: string,
  patch: Partial<SearchSessionRecord>
): void {
  const prev = sessions.get(sessionId);
  if (!prev) return;
  sessions.set(sessionId, { ...prev, ...patch });
}

export function setSearchSessionFailed(sessionId: string, message: string, payload?: unknown): void {
  const prev = sessions.get(sessionId);
  if (!prev) return;
  sessions.set(sessionId, {
    ...prev,
    status: 'failed',
    errorMessage: message,
    errorPayload: payload,
  });
}

export function setSearchSessionCompleted(
  sessionId: string,
  result: AnalyzeSearchResponse,
  searchQuery: string
): void {
  const prev = sessions.get(sessionId);
  if (!prev) return;
  sessions.set(sessionId, {
    ...prev,
    status: 'completed',
    result,
    searchQuery,
  });
}

export function getSearchSession(sessionId: string): SearchSessionRecord | undefined {
  return sessions.get(sessionId);
}
