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

export interface ProviderTaskResult {
  name: ProviderName;
  ms: number;
  listings: MarketplaceListingDTO[];
  status: 'ok' | 'timeout' | 'error';
}

export interface ParallelSearchOutcome {
  snapshot: ProviderTaskResult[];
  moreProvidersPending: boolean;
}

/** Snapshot figé au moment où la barrière se libère (≥ minComplete OU wall time). */
export async function runProvidersWithEarlyCutoff(
  tasks: Array<{
    name: ProviderName;
    timeoutMs: number;
    run: () => Promise<MarketplaceListingDTO[]>;
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
        const listings = await withTimeout(t.timeoutMs, t.name, t.run);
        const ms = Math.round(performance.now() - p0);
        results.push({ name: t.name, ms, listings, status: 'ok' });
        console.log(
          `[PERF] ${t.name}=${ms}ms results=${listings.length} (see PROVIDER_SUCCESS for details)`
        );
      } catch (e) {
        const ms = Math.round(performance.now() - p0);
        const msg = e instanceof Error ? e.message : String(e);
        const isTimeout =
          /\btimeout after \d+ms\b/i.test(msg) || msg.includes('timeout:');
        const status: ProviderTaskResult['status'] = isTimeout
          ? 'timeout'
          : 'error';
        results.push({ name: t.name, ms, listings: [], status });
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
    if (r.status === 'timeout' || r.status === 'error') {
      if (r.name === 'vinted') o.vintedSearchFailed = true;
      if (r.name === 'grailed') o.grailedSearchFailed = true;
      if (r.name === 'ebay') o.ebaySearchFailed = true;
      if (r.name === 'leboncoin') o.leboncoinSearchFailed = true;
      if (r.name === 'depop') o.depopSearchFailed = true;
    }
  }
  return o;
}
