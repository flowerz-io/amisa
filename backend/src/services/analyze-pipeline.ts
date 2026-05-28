import type {
  AnalyzeSearchBody,
  AnalyzeSearchResponseJSON,
  MarketplaceListingDTO,
  VintedPaginationDTO,
} from '../types.js';
import { gateVintedServer } from '../lib/provider-env.js';
import {
  failedFlagsFromResults,
  mergeAndCapListings,
  PROVIDER_TIMEOUT_MS,
  runProvidersAllSettled,
  type ProviderRunResult,
  type ProviderTaskResult,
} from '../lib/parallel-providers.js';
import { putSearchSession } from '../lib/search-session-store.js';
import { visionProviderName } from '../config.js';
import { buildPrimaryQueries } from '../lib/query-from-vision.js';
import { generateVintedQueries } from './search/generate-vinted-queries.js';
import { analyzeFashionVision } from './vision/analyze-fashion-vision.js';
import { searchVintedListingsWithMeta } from './marketplace-search.js';
import { ProviderScrapeError } from '../lib/provider-scrape-error.js';
import { PlaywrightChromiumMissingError } from '../lib/playwright-browser.js';

/** Ne garde que `vinted` si le client envoie d’anciennes clés multi-marketplaces. */
function vintedOnlyEnabled(body: AnalyzeSearchBody): Set<string> {
  const raw = body.enabledProviders;
  if (!raw?.length) return new Set(['vinted']);
  const set = new Set<string>();
  for (const s of raw) {
    if (s.trim().toLowerCase() === 'vinted') set.add('vinted');
  }
  return set;
}

function logSkipped(provider: string, reason: string): void {
  console.log(`[PROVIDER_DISABLED] ${provider} reason=${reason}`);
}

function runResultFromVintedCatch(e: unknown): ProviderRunResult {
  if (e instanceof PlaywrightChromiumMissingError) {
    console.error('[PROVIDER_BROWSER_MISSING]', 'vinted', e.message);
    return {
      listings: [],
      runStatus: 'browser_missing',
      reason: e.message,
    };
  }
  if (e instanceof ProviderScrapeError) {
    const blocked = e.blocked403 || e.httpStatus === 403;
    console.error('[PROVIDER_ERROR]', 'vinted', e.message, {
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
  console.error('[PROVIDER_ERROR]', 'vinted', msg);
  return { listings: [], runStatus: 'error', reason: msg };
}

function logAnalyzeResponseCounts(listings: MarketplaceListingDTO[]): void {
  console.log(`[ANALYZE_RESPONSE] total=${listings.length} (Vinted uniquement)`);
}

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
  let queries: string[];
  if (body.textQuery && body.textQuery.trim().length > 0) {
    queries = [body.textQuery.trim()];
  } else if (visionProviderName === 'gemini') {
    const brand = (vision.probableBrand ?? '').trim();
    const model = (vision.exactModel ?? vision.inferredModel ?? '').trim();
    const exactColorway = (vision.colorway ?? vision.dominantColorPrecise ?? '').trim();
    const dominantColor = (vision.color ?? '').trim();
    const secondaryColor = (vision.styleKeywords?.[0] ?? '').trim();
    const generated = generateVintedQueries({
      brand,
      model,
      exactColorway,
      dominantColor,
      secondaryColor,
    });
    queries =
      generated.queries.length > 0
        ? generated.queries
        : buildPrimaryQueries(vision);
    console.log(`[VINTED_QUERIES] ${JSON.stringify(queries)}`);
  } else {
    queries = buildPrimaryQueries(vision);
    console.log(`[VINTED_QUERIES] ${JSON.stringify(queries)}`);
  }

  const qGenMs = Math.round(performance.now() - qGenStart);
  console.log(`[PERF] query_generation=${qGenMs}ms`);

  const enabled = vintedOnlyEnabled(body);
  const gate = gateVintedServer();
  const opts = options ?? {};

  let listings: MarketplaceListingDTO[] = [];
  let vintedSearchFailed: boolean | undefined;
  let searchDebugMessage: string | undefined;
  let primaryHasMore = false;

  function summarizeVintedTask(row: ProviderTaskResult): string {
    const reason = row.reason ?? row.status;
    return `Vinted : ${reason}`;
  }

  if (!enabled.has('vinted')) {
    searchDebugMessage =
      'Vinted n’est pas activé dans la requête. Active-le dans Réglages.';
  } else if (!gate.ready) {
    logSkipped('vinted', gate.reason);
    searchDebugMessage = `Vinted indisponible sur le serveur (${gate.reason}).`;
    vintedSearchFailed = true;
  } else {
    const metaHolder = { primaryHasMore: false };
    const snapshot = await runProvidersAllSettled([
      {
        name: 'vinted',
        timeoutMs: PROVIDER_TIMEOUT_MS.vinted,
        run: async (): Promise<ProviderRunResult> => {
          try {
            const r = await searchVintedListingsWithMeta(queries, {
              maxMergedListings: 25,
              maxQueries: 3,
            });
            metaHolder.primaryHasMore = r.primaryHasMore;
            console.log('[RESULTS_BATCH]', {
              phase: 'analyze_initial',
              count: r.listings.length,
              hasMore: r.primaryHasMore,
            });
            return { listings: r.listings, runStatus: 'success' };
          } catch (e) {
            return runResultFromVintedCatch(e);
          }
        },
      },
    ]);
    const r0 = snapshot[0]!;
    const merged = mergeAndCapListings(
      r0.status === 'success' ? [r0.listings] : [[]],
      25
    );
    listings = merged.listings;
    console.log('[VISIBLE_RESULTS]', { analyzePipe: listings.length });
    primaryHasMore = metaHolder.primaryHasMore;

    const failed = failedFlagsFromResults(snapshot, enabled);

    if (listings.length === 0) {
      vintedSearchFailed = failed.vintedSearchFailed ?? true;
      searchDebugMessage =
        r0.status === 'success'
          ? 'Aucune annonce Vinted trouvée pour cette recherche.'
          : summarizeVintedTask(r0);
    } else {
      vintedSearchFailed = failed.vintedSearchFailed;
    }
  }

  logAnalyzeResponseCounts(listings);

  const primaryQuery = (queries[0] ?? '').trim();
  let pagination: VintedPaginationDTO | undefined;
  if (
    enabled.has('vinted') &&
    gate.ready &&
    primaryQuery.length > 0 &&
    listings.length > 0
  ) {
    pagination = {
      primaryQuery,
      nextPage: 2,
      hasMore: primaryHasMore,
      loadedCount: listings.length,
    };
  }

  const response: AnalyzeSearchResponseJSON = {
    status: 'completed',
    searchSessionId: opts.fixedSessionId,
    visionResult: vision,
    generatedQueries: queries,
    listings,
    pagination,
    vintedSearchFailed: listings.length > 0 ? undefined : vintedSearchFailed,
    initialResponseTimeMs: Math.round(performance.now() - wall),
    searchDebugMessage,
  };

  if (opts.fixedSessionId) {
    putSearchSession(opts.fixedSessionId, {
      pollStatus: 'completed',
      response,
    });
  }

  const total = Math.round(performance.now() - wall);
  console.log(`[PERF] total=${total}ms`);

  return response;
}