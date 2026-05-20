import { randomUUID } from 'node:crypto';
import type { AnalyzeSearchResponseJSON } from '../types.js';

export type SearchSessionPollStatus =
  | 'queued'
  | 'running'
  | 'partial'
  | 'completed'
  | 'failed';

export type StoredSearchSession = {
  pollStatus: SearchSessionPollStatus;
  response?: AnalyzeSearchResponseJSON;
  error?: string;
};

const sessions = new Map<string, StoredSearchSession>();

export function newSearchSessionId(): string {
  return randomUUID();
}

export function putSearchSession(
  sessionId: string,
  data: StoredSearchSession
): void {
  sessions.set(sessionId, data);
  const st = data.pollStatus;
  const lc = data.response?.listings?.length ?? 0;
  console.log(
    `[SEARCH_SESSION_UPDATED] id=${sessionId} pollStatus=${st} listings=${lc}`
  );
}

export function getSearchSession(
  sessionId: string
): StoredSearchSession | undefined {
  return sessions.get(sessionId);
}
