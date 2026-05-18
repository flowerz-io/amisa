import type {
  AnalyzeSearchBody,
  AnalyzeSearchResponseJSON,
  ProviderStatusDTO,
} from '../types.js';
import {
  gateDepopServer,
  gateEbayServer,
  gateGrailedServer,
  gateLeboncoinServer,
  gateVintedServer,
} from '../lib/provider-env.js';
import {
  failedFlagsFromResults,
  mergeAndCapListings,
  PROVIDER_TIMEOUT_MS,
  runProvidersWithEarlyCutoff,
  type ProviderName,
  type ProviderRunResult,
  type ProviderTaskResult,
} from '../lib/parallel-providers.js';
import { analyzeFashionVision } from './vision-openai.js';
import { buildPrimaryQueries } from '../lib/query-from-vision.js';
import {
  searchDepopListings,
  searchEbayListings,
  searchGrailedListings,
  searchLeboncoinListings,
  searchVintedListings,
} from './marketplace-search.js';
import { EbayRateLimitedError } from './providers/ebay-browse-search.js';

const GLOBAL_WAIT_MS = 15_000;
const MIN_PROVIDERS_DONE = 2;

const USE_MOCK =
  process.env.USE_MOCK?.toLowerCase() === 'true' ||
  process.env.MOCK_MODE?.toLowerCase() === 'true';

function logSkipped(provider: string, reason: string): void {
  console.log(`[PROVIDER_DISABLED] ${provider} reason=${reason}`);
}

function taskResultToDTO(r: ProviderTaskResult): ProviderStatusDTO {
  return {
    provider: r.name,
    status: r.status,
    reason: r.reason,
    listingsCount: r.listings.length,
    durationMs: r.ms,
  };
}

async function adaptVinted(queries: string[]): Promise<ProviderRunResult> {
  try {
    const listings = await searchVintedListings(queries);
    return { listings, runStatus: 'success' };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[PROVIDER_ERROR] vinted', msg);
    return { listings: [], runStatus: 'error', reason: msg };
  }
}

async function adaptEbay(queries: string[]): Promise<ProviderRunResult> {
  try {
    const listings = await searchEbayListings(queries);
    return { listings, runStatus: 'success' };
  } catch (e) {
    if (e instanceof EbayRateLimitedError) {
      console.log('[EBAY_RATE_LIMITED]', e.message);
      console.log('[PROVIDER_ERROR] ebay reason=rate_limited');
      return { listings: [], runStatus: 'rate_limited', reason: e.message };
    }
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[PROVIDER_ERROR] ebay', msg);
    return { listings: [], runStatus: 'error', reason: msg };
  }
}

async function adaptGrailed(queries: string[]): Promise<ProviderRunResult> {
  if (USE_MOCK) {
    try {
      const listings = await searchGrailedListings(queries);
      return { listings, runStatus: 'success' };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { listings: [], runStatus: 'error', reason: msg };
    }
  }
  logSkipped('grailed', 'not_implemented');
  return {
    listings: [],
    runStatus: 'disabled',
    reason: 'Provider not implemented',
  };
}

async function adaptDepop(queries: string[]): Promise<ProviderRunResult> {
  if (USE_MOCK) {
    try {
      const listings = await searchDepopListings(queries);
      return { listings, runStatus: 'success' };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { listings: [], runStatus: 'error', reason: msg };
    }
  }
  logSkipped('depop', 'not_implemented');
  return {
    listings: [],
    runStatus: 'disabled',
    reason: 'Provider not implemented',
  };
}

async function adaptLeboncoin(queries: string[]): Promise<ProviderRunResult> {
  if (USE_MOCK) {
    try {
      const listings = await searchLeboncoinListings(queries);
      return { listings, runStatus: 'success' };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { listings: [], runStatus: 'error', reason: msg };
    }
  }
  logSkipped('leboncoin', 'not_implemented');
  return {
    listings: [],
    runStatus: 'disabled',
    reason: 'Provider not implemented',
  };
}

export async function runAnalyzePipeline(
  body: AnalyzeSearchBody
): Promise<AnalyzeSearchResponseJSON> {
  const wall = performance.now();
  console.log('[PERF] image received');

  const vision = await analyzeFashionVision(body.imageBase64, body.textQuery);

  const qGenStart = performance.now();
  const queries =
    body.textQuery && body.textQuery.trim().length > 0
      ? [body.textQuery.trim()].slice(0, 2)
      : buildPrimaryQueries(vision);

  const qGenMs = Math.round(performance.now() - qGenStart);
  console.log(
    `[PERF] query_generation=${qGenMs}ms queries=${JSON.stringify(queries)}`
  );

  const enabled = new Set(
    (body.enabledProviders ?? []).map((s) => s.toLowerCase())
  );

  const providerStatuses: ProviderStatusDTO[] = [];

  const tasks: Array<{
    name: ProviderName;
    timeoutMs: number;
    run: () => Promise<ProviderRunResult>;
  }> = [];

  if (enabled.has('vinted')) {
    const g = gateVintedServer();
    if (!g.ready) {
      logSkipped('vinted', g.reason);
      providerStatuses.push({
        provider: 'vinted',
        status: 'skipped',
        reason: g.reason,
        listingsCount: 0,
      });
    } else {
      tasks.push({
        name: 'vinted',
        timeoutMs: PROVIDER_TIMEOUT_MS.vinted,
        run: () => adaptVinted(queries),
      });
    }
  }

  if (enabled.has('ebay')) {
    const g = gateEbayServer();
    if (!g.ready) {
      logSkipped('ebay', g.reason);
      providerStatuses.push({
        provider: 'ebay',
        status: 'skipped',
        reason: g.reason,
        listingsCount: 0,
      });
    } else {
      tasks.push({
        name: 'ebay',
        timeoutMs: PROVIDER_TIMEOUT_MS.ebay,
        run: () => adaptEbay(queries),
      });
    }
  }

  if (enabled.has('grailed')) {
    const g = gateGrailedServer();
    if (!g.ready) {
      logSkipped('grailed', g.reason);
      providerStatuses.push({
        provider: 'grailed',
        status: 'skipped',
        reason: g.reason,
        listingsCount: 0,
      });
    } else {
      tasks.push({
        name: 'grailed',
        timeoutMs: PROVIDER_TIMEOUT_MS.grailed,
        run: () => adaptGrailed(queries),
      });
    }
  }

  if (enabled.has('depop')) {
    const g = gateDepopServer();
    if (!g.ready) {
      logSkipped('depop', g.reason);
      providerStatuses.push({
        provider: 'depop',
        status: 'skipped',
        reason: g.reason,
        listingsCount: 0,
      });
    } else {
      tasks.push({
        name: 'depop',
        timeoutMs: PROVIDER_TIMEOUT_MS.depop,
        run: () => adaptDepop(queries),
      });
    }
  }

  if (enabled.has('leboncoin')) {
    const g = gateLeboncoinServer();
    if (!g.ready) {
      logSkipped('leboncoin', g.reason);
      providerStatuses.push({
        provider: 'leboncoin',
        status: 'skipped',
        reason: g.reason,
        listingsCount: 0,
      });
    } else {
      tasks.push({
        name: 'leboncoin',
        timeoutMs: PROVIDER_TIMEOUT_MS.leboncoin,
        run: () => adaptLeboncoin(queries),
      });
    }
  }

  console.log('[PROVIDERS_ACTIVE]', tasks.map((t) => t.name));

  let snapshot: ProviderTaskResult[] = [];
  let moreProvidersPending = false;

  try {
    if (tasks.length > 0) {
      const outcome = await runProvidersWithEarlyCutoff(tasks, {
        minComplete: Math.min(MIN_PROVIDERS_DONE, Math.max(1, tasks.length)),
        maxWallMs: GLOBAL_WAIT_MS,
      });
      snapshot = outcome.snapshot;
      moreProvidersPending = outcome.moreProvidersPending;
      providerStatuses.push(...snapshot.map(taskResultToDTO));
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[ANALYZE_PIPELINE] parallel_exception', msg);
    providerStatuses.push({
      provider: 'parallel',
      status: 'error',
      reason: msg,
      listingsCount: 0,
    });
  }

  const chunks = snapshot
    .filter((r) => r.status === 'ok')
    .map((r) => r.listings);
  const listings = mergeAndCapListings(chunks);
  const mergeMs = Math.round(performance.now() - wall);
  console.log(`[PERF] merge=${mergeMs}ms total_listings=${listings.length}`);

  const total = Math.round(performance.now() - wall);
  console.log(`[PERF] total=${total}ms`);

  const failed = failedFlagsFromResults(snapshot, enabled);

  let searchDebugMessage: string | undefined;
  if (listings.length === 0) {
    const summary = providerStatuses
      .map((s) => `${s.provider}=${s.status}${s.reason ? `:${s.reason}` : ''}`)
      .join('; ');
    searchDebugMessage = summary
      ? `Aucune annonce fusionnée. ${summary}`
      : 'Aucun provider exécuté (vérifie enabledProviders côté app et *_ENABLED sur Railway).';
  }

  return {
    visionResult: vision,
    generatedQueries: queries,
    listings,
    vintedSearchFailed: enabled.has('vinted') ? failed.vintedSearchFailed : undefined,
    grailedSearchFailed: enabled.has('grailed')
      ? failed.grailedSearchFailed
      : undefined,
    ebaySearchFailed: enabled.has('ebay') ? failed.ebaySearchFailed : undefined,
    leboncoinSearchFailed: enabled.has('leboncoin')
      ? failed.leboncoinSearchFailed
      : undefined,
    depopSearchFailed: enabled.has('depop') ? failed.depopSearchFailed : undefined,
    initialResponseTimeMs: total,
    moreProvidersPending: tasks.length > 0 ? moreProvidersPending : false,
    providerStatuses,
    searchDebugMessage,
  };
}