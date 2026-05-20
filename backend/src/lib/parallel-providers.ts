import type { MarketplaceListingDTO } from '../types.js';
import { marketplaceListingDedupeKey } from './listing-dedupe.js';
import { getMaxResultsPerSearch } from './search-limits.js';
import { withTimeout } from './with-timeout.js';

export type ProviderName = 'vinted';

export const PROVIDER_TIMEOUT_MS: Record<ProviderName, number> = {
  /** Playwright (catalogue / anti-bot lent). */
  vinted: 50_000,
};

/** Retour attendu par chaque tâche provider (sans throw en usage nominal). */
export interface ProviderRunResult {
  listings: MarketplaceListingDTO[];
  runStatus:
    | 'success'
    | 'disabled'
    | 'rate_limited'
    | 'error'
    | 'blocked'
    | 'blocked_403'
    | 'browser_missing';
  reason?: string;
  /** Statut HTTP quand erreur scraping / blocage réseau. */
  httpStatus?: number;
}

export interface ProviderTaskResult {
  name: ProviderName;
  ms: number;
  listings: MarketplaceListingDTO[];
  status:
    | 'success'
    | 'timeout'
    | 'error'
    | 'disabled'
    | 'rate_limited'
    | 'blocked'
    | 'blocked_403'
    | 'browser_missing';
  reason?: string;
  httpStatus?: number;
}

function mapRunResult(r: ProviderRunResult): {
  listings: MarketplaceListingDTO[];
  status: ProviderTaskResult['status'];
  reason?: string;
  httpStatus?: number;
} {
  switch (r.runStatus) {
    case 'success':
      return { listings: r.listings, status: 'success', reason: r.reason };
    case 'disabled':
      return { listings: [], status: 'disabled', reason: r.reason };
    case 'rate_limited':
      return { listings: [], status: 'rate_limited', reason: r.reason };
    case 'blocked_403':
      return {
        listings: [],
        status: 'blocked_403',
        reason: r.reason,
        httpStatus: r.httpStatus ?? 403,
      };
    case 'blocked':
      return {
        listings: [],
        status: 'blocked',
        reason: r.reason,
        httpStatus: r.httpStatus ?? 403,
      };
    case 'browser_missing':
      return {
        listings: [],
        status: 'browser_missing',
        reason: r.reason ?? 'playwright chromium manquant sur le runtime',
      };
    case 'error':
      return {
        listings: [],
        status: 'error',
        reason: r.reason,
        httpStatus: r.httpStatus,
      };
    default:
      return { listings: [], status: 'error', reason: 'unknown_run_status' };
  }
}

function isTimeoutMessage(msg: string): boolean {
  return /\btimeout after \d+ms\b/i.test(msg) || msg.includes('timeout:');
}

function isRetriableTimeoutOrNetwork(msg: string): boolean {
  if (isTimeoutMessage(msg)) return true;
  const m = msg.toLowerCase();
  if (m.includes('fetch failed')) return true;
  if (m.includes('econnrefused')) return true;
  if (m.includes('econnreset')) return true;
  if (m.includes('etimedout')) return true;
  if (m.includes('socket hang up')) return true;
  if (m.includes('networkconnectionlost')) return true;
  if (m.includes('connection reset')) return true;
  return false;
}

async function withTimeoutMaybeRetry(
  timeoutMs: number,
  label: ProviderName,
  run: () => Promise<ProviderRunResult>
): Promise<ProviderRunResult> {
  try {
    return await withTimeout(timeoutMs, label, run);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (!isRetriableTimeoutOrNetwork(msg)) throw e;
    console.log(
      `[PROVIDER_RETRY] provider=${label} reason=${JSON.stringify(msg.slice(0, 200))}`
    );
    return await withTimeout(timeoutMs, label, run);
  }
}

function logProviderResult(r: ProviderTaskResult): void {
  const reason = r.reason ?? '';
  const hs =
    r.httpStatus !== undefined ? ` httpStatus=${r.httpStatus}` : '';
  console.log(
    `[PROVIDER_RESULT] provider=${r.name} durationMs=${r.ms} count=${r.listings.length} status=${r.status}${hs} reason=${JSON.stringify(reason.slice(0, 500))}`
  );
}

export async function runProvidersAllSettled(
  tasks: Array<{
    name: ProviderName;
    timeoutMs: number;
    run: () => Promise<ProviderRunResult>;
  }>
): Promise<ProviderTaskResult[]> {
  const settled = await Promise.allSettled(
    tasks.map((t) => runOneProviderTask(t))
  );

  const out: ProviderTaskResult[] = [];
  for (let i = 0; i < tasks.length; i++) {
    const t = tasks[i]!;
    const s = settled[i]!;
    if (s.status === 'fulfilled') {
      out.push(s.value);
    } else {
      const msg =
        s.reason instanceof Error ? s.reason.message : String(s.reason);
      const row: ProviderTaskResult = {
        name: t.name,
        ms: 0,
        listings: [],
        status: 'error',
        reason: `unexpected_parallel_rejection: ${msg}`,
        httpStatus: undefined,
      };
      logProviderResult(row);
      out.push(row);
    }
  }

  return out;
}

async function runOneProviderTask(t: {
  name: ProviderName;
  timeoutMs: number;
  run: () => Promise<ProviderRunResult>;
}): Promise<ProviderTaskResult> {
  const p0 = performance.now();
  try {
    const outcome = await withTimeoutMaybeRetry(t.timeoutMs, t.name, t.run);
    const mapped = mapRunResult(outcome);
    const ms = Math.round(performance.now() - p0);
    const row: ProviderTaskResult = {
      name: t.name,
      ms,
      listings: mapped.listings,
      status: mapped.status,
      reason: mapped.reason,
      httpStatus: mapped.httpStatus,
    };
    logProviderResult(row);
    return row;
  } catch (e) {
    const ms = Math.round(performance.now() - p0);
    const msg = e instanceof Error ? e.message : String(e);
    const status: ProviderTaskResult['status'] = isTimeoutMessage(msg)
      ? 'timeout'
      : 'error';
    const row: ProviderTaskResult = {
      name: t.name,
      ms,
      listings: [],
      status,
      reason: msg,
      httpStatus: undefined,
    };
    logProviderResult(row);
    return row;
  }
}

export interface MergeAndCapStats {
  chunkCounts: number[];
  inputSum: number;
  afterDedupAndCap: number;
  maxCap: number;
  dedupeSkips: number;
  perProviderSkips: number;
}

export function mergeAndCapListings(
  chunks: MarketplaceListingDTO[][],
  maxCapOverride?: number
): { listings: MarketplaceListingDTO[]; stats: MergeAndCapStats } {
  const maxCap =
    typeof maxCapOverride === 'number' && maxCapOverride > 0
      ? Math.min(maxCapOverride, getMaxResultsPerSearch())
      : getMaxResultsPerSearch();
  const queues = chunks.map((c) => [...c]);
  const chunkCounts = chunks.map((c) => c.length);
  const inputSum = chunkCounts.reduce((a, b) => a + b, 0);

  const seen = new Set<string>();
  const out: MarketplaceListingDTO[] = [];
  let dedupeSkips = 0;

  while (out.length < maxCap) {
    let tookThisRound = false;
    for (const q of queues) {
      if (out.length >= maxCap) break;
      while (q.length > 0) {
        const L = q[0]!;
        const key = marketplaceListingDedupeKey(L);
        if (seen.has(key)) {
          q.shift();
          dedupeSkips += 1;
          continue;
        }
        q.shift();
        seen.add(key);
        out.push(L);
        tookThisRound = true;
        break;
      }
    }
    if (!tookThisRound) break;
  }

  const stats: MergeAndCapStats = {
    chunkCounts,
    inputSum,
    afterDedupAndCap: out.length,
    maxCap,
    dedupeSkips,
    perProviderSkips: 0,
  };

  console.log('[LISTINGS_MERGE]', {
    chunkCounts: stats.chunkCounts,
    inputSum: stats.inputSum,
    afterDedupAndCap: stats.afterDedupAndCap,
    maxCap: stats.maxCap,
    dedupeSkips: stats.dedupeSkips,
    mode: 'round_robin',
  });

  return { listings: out, stats };
}

export function failedFlagsFromResults(
  results: ProviderTaskResult[],
  enabled: Set<string>
): { vintedSearchFailed?: boolean } {
  const o: { vintedSearchFailed?: boolean } = {};

  for (const r of results) {
    if (!enabled.has(r.name)) continue;
    const hard =
      r.status === 'timeout' ||
      r.status === 'error' ||
      r.status === 'rate_limited';
    if (!hard) continue;
    if (r.name === 'vinted') o.vintedSearchFailed = true;
  }
  return o;
}
