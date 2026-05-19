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
  runProvidersAllSettled,
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
import { ProviderScrapeError } from '../lib/provider-scrape-error.js';

function logSkipped(provider: string, reason: string): void {
  console.log(`[PROVIDER_DISABLED] ${provider} reason=${reason}`);
}

function runResultFromScrapeCatch(
  provider: string,
  e: unknown
): ProviderRunResult {
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

  const lcSrv = gateLeboncoinServer();
  if (lcSrv.ready) {
    if (!enabled.has('leboncoin')) {
      console.log(
        '[ENABLED_MERGE] leboncoin ajouté côté serveur (LEBONCOIN_ENABLED=true)'
      );
    }
    enabled.add('leboncoin');
  }

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

  if (tasks.length > 0) {
    console.log('[PROVIDERS_PARALLEL] mode=allSettled tasks=', tasks.length);
    snapshot = await runProvidersAllSettled(tasks);
    providerStatuses.push(...snapshot.map(taskResultToDTO));
  }

  const chunks = snapshot
    .filter((r) => r.status === 'success')
    .map((r) => r.listings);
  const { listings, stats: mergeStats } = mergeAndCapListings(chunks);
  const mergeMs = Math.round(performance.now() - wall);
  console.log(
    `[PERF] merge=${mergeMs}ms total_listings=${listings.length} merge_input_sum=${mergeStats.inputSum} merge_after_dedup_cap=${mergeStats.afterDedupAndCap} merge_max_cap=${mergeStats.maxCap}`
  );
  console.log('[PERF] final_listings_to_client', listings.length);

  const total = Math.round(performance.now() - wall);
  console.log(`[PERF] total=${total}ms`);

  const failed = failedFlagsFromResults(snapshot, enabled);

  /** Dès qu’au moins un listing est renvoyé (ex. eBay OK), on n’expose plus les échecs partiels en flags top-level. */
  const hideTopLevelSearchFailures = listings.length > 0;

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
    vintedSearchFailed: hideTopLevelSearchFailures
      ? undefined
      : enabled.has('vinted')
        ? failed.vintedSearchFailed
        : undefined,
    grailedSearchFailed: hideTopLevelSearchFailures
      ? undefined
      : enabled.has('grailed')
        ? failed.grailedSearchFailed
        : undefined,
    ebaySearchFailed: hideTopLevelSearchFailures
      ? undefined
      : enabled.has('ebay')
        ? failed.ebaySearchFailed
        : undefined,
    leboncoinSearchFailed: hideTopLevelSearchFailures
      ? undefined
      : enabled.has('leboncoin')
        ? failed.leboncoinSearchFailed
        : undefined,
    depopSearchFailed: hideTopLevelSearchFailures
      ? undefined
      : enabled.has('depop')
        ? failed.depopSearchFailed
        : undefined,
    initialResponseTimeMs: total,
    moreProvidersPending: false,
    providerStatuses,
    searchDebugMessage,
  };
}