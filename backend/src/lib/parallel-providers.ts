import type { MarketplaceListingDTO } from '../types.js';
import { sleep, withTimeout } from './with-timeout.js';

export type ProviderName = 'vinted' | 'ebay' | 'grailed' | 'depop' | 'leboncoin';

export const PROVIDER_TIMEOUT_MS: Record<ProviderName, number> = {
  vinted: 8000,
  ebay: 6000,
  grailed: 10000,
  depop: 8000,
  leboncoin: 10000,
};

const MAX_PER_PROVIDER = 30;
const MAX_TOTAL = 120;

/** Retour attendu par chaque tâche provider (sans throw en usage nominal). */
export interface ProviderRunResult {
  listings: MarketplaceListingDTO[];
  runStatus: 'success' | 'disabled' | 'rate_limited' | 'error';
  reason?: string;
}

export interface ProviderTaskResult {
  name: ProviderName;
  ms: number;
  listings: MarketplaceListingDTO[];
  status: 'ok' | 'timeout' | 'error' | 'disabled' | 'rate_limited';
  reason?: string;
}

export interface ParallelSearchOutcome {
  snapshot: ProviderTaskResult[];
  moreProvidersPending: boolean;
}

function mapRunResult(r: ProviderRunResult): {
  listings: MarketplaceListingDTO[];
  status: ProviderTaskResult['status'];
  reason?: string;
} {
  switch (r.runStatus) {
    case 'success':
      return { listings: r.listings, status: 'ok', reason: r.reason };
    case 'disabled':
      return { listings: [], status: 'disabled', reason: r.reason };
    case 'rate_limited':
      return { listings: [], status: 'rate_limited', reason: r.reason };
    case 'error':
      return { listings: [], status: 'error', reason: r.reason };
    default:
      return { listings: [], status: 'error', reason: 'unknown_run_status' };
  }
}

/** Snapshot figé au moment où la barrière se libère (≥ minComplete OU wall time). */
export async function runProvidersWithEarlyCutoff(
  tasks: Array<{
    name: ProviderName;
    timeoutMs: number;
    run: () => Promise<ProviderRunResult>;
  }>,
  opts: { minComplete: number; maxWallMs: number }
): Promise<ParallelSearchOutcome> {
  if (tasks.length === 0) {
    return { snapshot: [], moreProvidersPending: false };
  }
  const results: ProviderTaskResult[] = [];
  let completed = 0;
  const t0 = performance.now();
  let gateDone = false;
  let snapshot: ProviderTaskResult[] = [];

  let resolveGate!: () => void;
  const gate = new Promise<void>((r) => {
    resolveGate = r;
  });

  const release = () => {
    if (gateDone) return;
    gateDone = true;
    snapshot = results.slice();
    resolveGate();
  };

  const tryGate = () => {
    if (gateDone) return;
    const elapsed = performance.now() - t0;
    if (completed >= opts.minComplete || elapsed >= opts.maxWallMs) {
      release();
    }
  };

  for (const t of tasks) {
    const p0 = performance.now();
    void (async () => {
      try {
        const outcome = await withTimeout(t.timeoutMs, t.name, t.run);
        const mapped = mapRunResult(outcome);
        const ms = Math.round(performance.now() - p0);
        results.push({
          name: t.name,
          ms,
          listings: mapped.listings,
          status: mapped.status,
          reason: mapped.reason,
        });
        console.log(
          `[PERF] ${t.name}=${ms}ms results=${mapped.listings.length} status=${mapped.status}`
        );
      } catch (e) {
        const ms = Math.round(performance.now() - p0);
        const msg = e instanceof Error ? e.message : String(e);
        const isTimeout =
          /\btimeout after \d+ms\b/i.test(msg) || msg.includes('timeout:');
        const status: ProviderTaskResult['status'] = isTimeout
          ? 'timeout'
          : 'error';
        results.push({
          name: t.name,
          ms,
          listings: [],
          status,
          reason: msg,
        });
        console.error(`[PROVIDER_REJECTED] ${t.name}`, {
          status,
          durationMs: ms,
          reason: msg,
          stack: e instanceof Error ? e.stack : undefined,
        });
        if (status === 'timeout') {
          console.log(`[PERF] ${t.name}=timeout after ${ms}ms`);
        } else {
          console.log(`[PERF] ${t.name}=error after ${ms}ms`);
        }
      } finally {
        completed += 1;
        tryGate();
      }
    })();
  }

  await Promise.race([gate, sleep(opts.maxWallMs)]);
  if (!gateDone) release();

  const moreProvidersPending = snapshot.length < tasks.length;
  snapshot.sort((a, b) => a.name.localeCompare(b.name));
  return { snapshot, moreProvidersPending };
}

export function mergeAndCapListings(
  chunks: MarketplaceListingDTO[][]
): MarketplaceListingDTO[] {
  const perProv = new Map<string, number>();
  const seen = new Set<string>();
  const out: MarketplaceListingDTO[] = [];

  outer: for (const chunk of chunks) {
    for (const L of chunk) {
      const key = `${(L.source ?? '').toLowerCase()}|${L.id}`;
      if (seen.has(key)) continue;
      const prov = (L.source ?? 'unknown').toLowerCase();
      const n = perProv.get(prov) ?? 0;
      if (n >= MAX_PER_PROVIDER) continue;
      if (out.length >= MAX_TOTAL) break outer;
      seen.add(key);
      perProv.set(prov, n + 1);
      out.push(L);
    }
  }
  return out;
}

export function failedFlagsFromResults(
  results: ProviderTaskResult[],
  enabled: Set<string>
): {
  vintedSearchFailed?: boolean;
  grailedSearchFailed?: boolean;
  ebaySearchFailed?: boolean;
  leboncoinSearchFailed?: boolean;
  depopSearchFailed?: boolean;
} {
  const o: {
    vintedSearchFailed?: boolean;
    grailedSearchFailed?: boolean;
    ebaySearchFailed?: boolean;
    leboncoinSearchFailed?: boolean;
    depopSearchFailed?: boolean;
  } = {};

  for (const r of results) {
    if (!enabled.has(r.name)) continue;
    const hard =
      r.status === 'timeout' ||
      r.status === 'error' ||
      r.status === 'rate_limited';
    if (!hard) continue;
    if (r.name === 'vinted') o.vintedSearchFailed = true;
    if (r.name === 'grailed') o.grailedSearchFailed = true;
    if (r.name === 'ebay') o.ebaySearchFailed = true;
    if (r.name === 'leboncoin') o.leboncoinSearchFailed = true;
    if (r.name === 'depop') o.depopSearchFailed = true;
  }
  return o;
}
