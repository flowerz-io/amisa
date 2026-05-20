import type {
  AnalyzeSearchBody,
  AnalyzeSearchResponseJSON,
  FashionVisionResult,
  MarketplaceListingDTO,
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
  SLOW_PROVIDER_TIMEOUT_MS,
  runProvidersAllSettled,
  type ProviderName,
  type ProviderRunResult,
  type ProviderTaskResult,
} from '../lib/parallel-providers.js';
import {
  getSearchSession,
  newSearchSessionId,
  putSearchSession,
} from '../lib/search-session-store.js';
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
import { ProviderScrapeError } from '../lib/provider-scrape-error.js';
import { PlaywrightChromiumMissingError } from '../lib/playwright-browser.js';
import { GrailedBlockedError } from './providers/grailed-blocked.js';

function buildPublicProviderStatuses(
  rows: ProviderStatusDTO[]
): Record<string, string> {
  const m: Record<string, string> = {};
  for (const r of rows) {
    let st = r.status;
    if (st === 'blocked_403' || st === 'blocked') st = 'blocked';
    m[r.provider] = st;
  }
  return m;
}

function mergeRunningProviderStatuses(
  rows: ProviderStatusDTO[],
  runningSlowNames: string[]
): Record<string, string> {
  const m = buildPublicProviderStatuses(rows);
  for (const n of runningSlowNames) {
    m[n] = 'running';
  }
  return m;
}

function assembleAnalyzeResponse(params: {
  wall: number;
  vision: FashionVisionResult;
  queries: string[];
  listings: MarketplaceListingDTO[];
  providerRows: ProviderStatusDTO[];
  runningSlowNames: string[];
  searchStatus: 'partial' | 'completed';
  searchSessionId?: string;
  enabled: Set<string>;
  resultsForFlags: ProviderTaskResult[];
}): AnalyzeSearchResponseJSON {
  const failed = failedFlagsFromResults(params.resultsForFlags, params.enabled);
  const hideTopLevelSearchFailures = params.listings.length > 0;

  let searchDebugMessage: string | undefined;
  if (params.listings.length === 0) {
    const summary = params.providerRows
      .map((s) => `${s.provider}=${s.status}${s.reason ? `:${s.reason}` : ''}`)
      .join('; ');
    searchDebugMessage = summary
      ? `Aucune annonce fusionnée. ${summary}`
      : 'Aucun provider exécuté (vérifie enabledProviders côté app et *_ENABLED sur Railway).';
  }

  logAnalyzeResponseCounts(params.listings);

  return {
    status: params.searchStatus,
    searchSessionId: params.searchSessionId,
    visionResult: params.vision,
    generatedQueries: params.queries,
    listings: params.listings,
    vintedSearchFailed: hideTopLevelSearchFailures
      ? undefined
      : params.enabled.has('vinted')
        ? failed.vintedSearchFailed
        : undefined,
    grailedSearchFailed: hideTopLevelSearchFailures
      ? undefined
      : params.enabled.has('grailed')
        ? failed.grailedSearchFailed
        : undefined,
    ebaySearchFailed: hideTopLevelSearchFailures
      ? undefined
      : params.enabled.has('ebay')
        ? failed.ebaySearchFailed
        : undefined,
    leboncoinSearchFailed: hideTopLevelSearchFailures
      ? undefined
      : params.enabled.has('leboncoin')
        ? failed.leboncoinSearchFailed
        : undefined,
    depopSearchFailed: hideTopLevelSearchFailures
      ? undefined
      : params.enabled.has('depop')
        ? failed.depopSearchFailed
        : undefined,
    initialResponseTimeMs: Math.round(performance.now() - params.wall),
    moreProvidersPending: params.searchStatus === 'partial',
    providerStatuses: mergeRunningProviderStatuses(
      params.providerRows,
      params.runningSlowNames
    ),
    providerStatusReasons: buildPublicProviderStatusReasons(params.providerRows),
    searchDebugMessage,
  };
}

function buildPublicProviderStatusReasons(
  rows: ProviderStatusDTO[]
): Record<string, string> | undefined {
  const m: Record<string, string> = {};
  for (const r of rows) {
    if (r.status !== 'blocked' && r.status !== 'blocked_403') continue;
    if (r.provider === 'grailed' && r.reason === 'grailed_cloudflare') {
      m.grailed = 'grailed_cloudflare';
    } else if (r.reason) {
      m[r.provider] = r.reason.slice(0, 200);
    }
  }
  return Object.keys(m).length ? m : undefined;
}

function logAnalyzeResponseCounts(listings: MarketplaceListingDTO[]): void {
  let ebay = 0;
  let vinted = 0;
  let grailed = 0;
  let depop = 0;
  for (const L of listings) {
    const s = (L.source ?? '').trim().toLowerCase();
    if (s.includes('ebay')) ebay += 1;
    else if (s.includes('vinted')) vinted += 1;
    else if (s.includes('grailed')) grailed += 1;
    else if (s.includes('depop')) depop += 1;
  }
  console.log(
    `[ANALYZE_RESPONSE] total=${listings.length} ebay=${ebay} vinted=${vinted} depop=${depop} grailed=${grailed}`
  );
}

function logSkipped(provider: string, reason: string): void {
  console.log(`[PROVIDER_DISABLED] ${provider} reason=${reason}`);
}

function runResultFromScrapeCatch(
  provider: string,
  e: unknown
): ProviderRunResult {
  if (e instanceof PlaywrightChromiumMissingError) {
    console.error(
      '[PROVIDER_BROWSER_MISSING]',
      provider,
      e.message
    );
    return {
      listings: [],
      runStatus: 'browser_missing',
      reason: e.message,
    };
  }
  if (e instanceof ProviderScrapeError) {
    const blocked = e.blocked403 || e.httpStatus === 403;
    console.error('[PROVIDER_ERROR]', provider, e.message, {
      httpStatus: e.httpStatus,
      blocked403: e.blocked403,
    });
    if (blocked) {
      return {
        listings: [],
        runStatus: 'blocked_403',
        reason: e.message,
        httpStatus: e.httpStatus ?? 403,
      };
    }
    return {
      listings: [],
      runStatus: 'error',
      reason: e.message,
      httpStatus: e.httpStatus,
    };
  }
  const msg = e instanceof Error ? e.message : String(e);
  console.error('[PROVIDER_ERROR]', provider, msg);
  return { listings: [], runStatus: 'error', reason: msg };
}

function taskResultToDTO(r: ProviderTaskResult): ProviderStatusDTO {
  const o: ProviderStatusDTO = {
    provider: r.name,
    status: r.status,
    reason: r.reason,
    listingsCount: r.listings.length,
    durationMs: r.ms,
  };
  if (r.httpStatus !== undefined) o.httpStatus = r.httpStatus;
  return o;
}

async function adaptVinted(queries: string[]): Promise<ProviderRunResult> {
  try {
    const listings = await searchVintedListings(queries);
    return { listings, runStatus: 'success' };
  } catch (e) {
    return runResultFromScrapeCatch('vinted', e);
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
  try {
    const listings = await searchGrailedListings(queries);
    return { listings, runStatus: 'success' };
  } catch (e) {
    if (e instanceof GrailedBlockedError) {
      console.log('[GRAILED_BLOCKED]', e.reasonCode);
      return {
        listings: [],
        runStatus: 'blocked',
        reason: e.reasonCode,
        httpStatus: 403,
      };
    }
    return runResultFromScrapeCatch('grailed', e);
  }
}

async function adaptDepop(queries: string[]): Promise<ProviderRunResult> {
  try {
    const listings = await searchDepopListings(queries);
    return { listings, runStatus: 'success' };
  } catch (e) {
    return runResultFromScrapeCatch('depop', e);
  }
}

async function adaptLeboncoin(queries: string[]): Promise<ProviderRunResult> {
  try {
    const listings = await searchLeboncoinListings(queries);
    return { listings, runStatus: 'success' };
  } catch (e) {
    return runResultFromScrapeCatch('leboncoin', e);
  }
}

/** eBay + Vinted d’abord ; Depop + Grailed + Leboncoin ensuite (timeouts plus longs). */
const FAST_ORDER: ProviderName[] = ['vinted', 'ebay'];
const SLOW_ORDER: ProviderName[] = ['grailed', 'depop', 'leboncoin'];

export type RunAnalyzePipelineOptions = {
  awaitSlowCompletion?: boolean;
  fixedSessionId?: string;
};

export async function runAnalyzePipeline(
  body: AnalyzeSearchBody,
  options?: RunAnalyzePipelineOptions
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

  const lcSrv = gateLeboncoinServer();
  if (lcSrv.ready) {
    if (!enabled.has('leboncoin')) {
      console.log(
        '[ENABLED_MERGE] leboncoin ajouté côté serveur (LEBONCOIN_ENABLED=true)'
      );
    }
    enabled.add('leboncoin');
  }

  const skippedRows: ProviderStatusDTO[] = [];
  const fastTasks: Array<{
    name: ProviderName;
    timeoutMs: number;
    run: () => Promise<ProviderRunResult>;
  }> = [];
  const slowTasks: Array<{
    name: ProviderName;
    timeoutMs: number;
    run: () => Promise<ProviderRunResult>;
  }> = [];

  const appendProvider = (name: ProviderName, bucket: 'fast' | 'slow') => {
    if (!enabled.has(name)) return;
    const gate =
      name === 'vinted'
        ? gateVintedServer()
        : name === 'ebay'
          ? gateEbayServer()
          : name === 'grailed'
            ? gateGrailedServer()
            : name === 'depop'
              ? gateDepopServer()
              : gateLeboncoinServer();
    if (!gate.ready) {
      logSkipped(name, gate.reason);
      skippedRows.push({
        provider: name,
        status: 'skipped',
        reason: gate.reason,
        listingsCount: 0,
      });
      return;
    }
    const timeoutMs =
      bucket === 'fast'
        ? PROVIDER_TIMEOUT_MS[name]
        : SLOW_PROVIDER_TIMEOUT_MS[name];
    const run =
      name === 'vinted'
        ? () => adaptVinted(queries)
        : name === 'ebay'
          ? () => adaptEbay(queries)
          : name === 'grailed'
            ? () => adaptGrailed(queries)
            : name === 'depop'
              ? () => adaptDepop(queries)
              : () => adaptLeboncoin(queries);
    const task = { name, timeoutMs, run };
    if (bucket === 'fast') fastTasks.push(task);
    else slowTasks.push(task);
  };

  for (const n of FAST_ORDER) appendProvider(n, 'fast');
  for (const n of SLOW_ORDER) appendProvider(n, 'slow');

  console.log(
    '[PROVIDERS_ACTIVE]',
    'fast=',
    fastTasks.map((t) => t.name),
    'slow=',
    slowTasks.map((t) => t.name)
  );

  let snapshotFast: ProviderTaskResult[] = [];
  if (fastTasks.length > 0) {
    snapshotFast = await runProvidersAllSettled(fastTasks);
  }

  console.log('[FAST_PROVIDERS_DONE]', {
    ms: Math.round(performance.now() - wall),
    results: snapshotFast.map((r) => ({
      provider: r.name,
      status: r.status,
      count: r.listings.length,
    })),
  });

  const rowsAfterFast: ProviderStatusDTO[] = [
    ...skippedRows,
    ...snapshotFast.map(taskResultToDTO),
  ];

  const fastChunks = snapshotFast
    .filter((r) => r.status === 'success')
    .map((r) => r.listings);
  const { listings: listingsFast, stats: mergeStatsFast } =
    mergeAndCapListings(fastChunks);

  console.log(
    `[PERF] merge_fast=${Math.round(performance.now() - wall)}ms total_listings=${listingsFast.length} merge_input_sum=${mergeStatsFast.inputSum} merge_after_dedup_cap=${mergeStatsFast.afterDedupAndCap} merge_max_cap=${mergeStatsFast.maxCap}`
  );
  console.log('[PERF] fast_listings_to_client', listingsFast.length);

  const slowNames = slowTasks.map((t) => t.name);
  const fastChunksFrozen = fastChunks;
  const opts = options ?? {};

  const runSlowPhase = async (
    sessionId: string,
    rowsBase: ProviderStatusDTO[]
  ): Promise<void> => {
    try {
      console.log('[SLOW_PROVIDERS_STARTED]', {
        searchSessionId: sessionId,
        providers: slowNames,
      });
      const snapshotSlow =
        slowTasks.length > 0 ? await runProvidersAllSettled(slowTasks) : [];
      for (const r of snapshotSlow) {
        console.log(
          `[SLOW_PROVIDER_DONE] ${r.name} count=${r.listings.length} status=${r.status}`
        );
      }
      const rowsComplete = [
        ...rowsBase,
        ...snapshotSlow.map(taskResultToDTO),
      ];
      const slowChunks = snapshotSlow
        .filter((r) => r.status === 'success')
        .map((r) => r.listings);
      const { listings: listingsAll, stats: mergeStatsSlow } =
        mergeAndCapListings([...fastChunksFrozen, ...slowChunks]);
      console.log(
        `[PERF] merge_slow total_listings=${listingsAll.length} merge_input_sum=${mergeStatsSlow.inputSum} merge_after_dedup_cap=${mergeStatsSlow.afterDedupAndCap}`
      );
      const snapshotAll = [...snapshotFast, ...snapshotSlow];
      const completed = assembleAnalyzeResponse({
        wall,
        vision,
        queries,
        listings: listingsAll,
        providerRows: rowsComplete,
        runningSlowNames: [],
        searchStatus: 'completed',
        searchSessionId: sessionId,
        enabled,
        resultsForFlags: snapshotAll,
      });
      putSearchSession(sessionId, {
        pollStatus: 'completed',
        response: completed,
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('[SLOW_PROVIDERS_FATAL]', sessionId, msg);
      const errored: ProviderStatusDTO[] = slowNames.map((n) => ({
        provider: n,
        status: 'error',
        reason: msg.slice(0, 300),
        listingsCount: 0,
      }));
      const rowsComplete = [...rowsBase, ...errored];
      const completed = assembleAnalyzeResponse({
        wall,
        vision,
        queries,
        listings: listingsFast,
        providerRows: rowsComplete,
        runningSlowNames: [],
        searchStatus: 'completed',
        searchSessionId: sessionId,
        enabled,
        resultsForFlags: snapshotFast,
      });
      putSearchSession(sessionId, {
        pollStatus: 'completed',
        response: completed,
      });
    }
  };

  /** Session Railway : GET /search-sessions — toujours l’UUID POST ; sinon seulement si phase lente. */
  const sessionIdForStore: string | undefined =
    opts.fixedSessionId ??
    (slowTasks.length > 0 ? newSearchSessionId() : undefined);

  if (slowTasks.length === 0) {
    const completed = assembleAnalyzeResponse({
      wall,
      vision,
      queries,
      listings: listingsFast,
      providerRows: rowsAfterFast,
      runningSlowNames: [],
      searchStatus: 'completed',
      searchSessionId: opts.fixedSessionId,
      enabled,
      resultsForFlags: snapshotFast,
    });
    const total = Math.round(performance.now() - wall);
    console.log(`[PERF] total=${total}ms (no_slow_providers)`);
    if (opts.fixedSessionId) {
      putSearchSession(opts.fixedSessionId, {
        pollStatus: 'completed',
        response: completed,
      });
    }
    return completed;
  }

  const sessionId = sessionIdForStore!;
  const partialResponse = assembleAnalyzeResponse({
    wall,
    vision,
    queries,
    listings: listingsFast,
    providerRows: rowsAfterFast,
    runningSlowNames: slowNames,
    searchStatus: 'partial',
    searchSessionId: sessionId,
    enabled,
    resultsForFlags: snapshotFast,
  });

  putSearchSession(sessionId, {
    pollStatus: 'partial',
    response: partialResponse,
  });

  const finishSlow = () => runSlowPhase(sessionId, rowsAfterFast);

  if (opts.awaitSlowCompletion) {
    await finishSlow();
    const total = Math.round(performance.now() - wall);
    console.log(`[PERF] total=${total}ms (await_slow)`);
    return getSearchSession(sessionId)?.response ?? partialResponse;
  }

  void finishSlow();
  const total = Math.round(performance.now() - wall);
  console.log(`[PERF] total=${total}ms (fast_path_return)`);
  return partialResponse;
}