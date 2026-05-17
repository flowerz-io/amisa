import type {
  AnalyzeSearchBody,
  AnalyzeSearchResponseJSON,
  MarketplaceListingDTO,
} from '../types.js';
import { analyzeFashionVision } from './vision-openai.js';
import { buildPrimaryQueries } from '../lib/query-from-vision.js';
import { isProviderRunnable } from '../lib/provider-env.js';
import {
  failedFlagsFromResults,
  mergeAndCapListings,
  PROVIDER_TIMEOUT_MS,
  runProvidersWithEarlyCutoff,
  type ProviderName,
} from '../lib/parallel-providers.js';
import {
  searchDepopListings,
  searchEbayListings,
  searchGrailedListings,
  searchLeboncoinListings,
  searchVintedListings,
} from './marketplace-search.js';

const GLOBAL_WAIT_MS = 15_000;
const MIN_PROVIDERS_DONE = 2;

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

  const tasks: Array<{
    name: ProviderName;
    timeoutMs: number;
    run: () => Promise<MarketplaceListingDTO[]>;
  }> = [];

  if (isProviderRunnable('vinted', enabled)) {
    tasks.push({
      name: 'vinted',
      timeoutMs: PROVIDER_TIMEOUT_MS.vinted,
      run: () => searchVintedListings(queries),
    });
  }
  if (isProviderRunnable('ebay', enabled)) {
    tasks.push({
      name: 'ebay',
      timeoutMs: PROVIDER_TIMEOUT_MS.ebay,
      run: () => searchEbayListings(queries),
    });
  }
  if (isProviderRunnable('grailed', enabled)) {
    tasks.push({
      name: 'grailed',
      timeoutMs: PROVIDER_TIMEOUT_MS.grailed,
      run: () => searchGrailedListings(queries),
    });
  }
  if (isProviderRunnable('depop', enabled)) {
    tasks.push({
      name: 'depop',
      timeoutMs: PROVIDER_TIMEOUT_MS.depop,
      run: () => searchDepopListings(queries),
    });
  }
  if (isProviderRunnable('leboncoin', enabled)) {
    tasks.push({
      name: 'leboncoin',
      timeoutMs: PROVIDER_TIMEOUT_MS.leboncoin,
      run: () => searchLeboncoinListings(queries),
    });
  }

  console.log(
    '[ANALYZE_SEARCH] provider_tasks=',
    tasks.map((t) => t.name),
    'queries=',
    queries
  );

  const mergeT0 = performance.now();
  const { snapshot: providerResults, moreProvidersPending } =
    await runProvidersWithEarlyCutoff(tasks, {
      minComplete: Math.min(MIN_PROVIDERS_DONE, Math.max(1, tasks.length)),
      maxWallMs: GLOBAL_WAIT_MS,
    });

  const chunks = providerResults
    .filter((r) => r.status === 'ok')
    .map((r) => r.listings);
  const listings = mergeAndCapListings(chunks);
  const mergeMs = Math.round(performance.now() - mergeT0);
  console.log(`[PERF] merge=${mergeMs}ms total_listings=${listings.length}`);

  const total = Math.round(performance.now() - wall);
  console.log(`[PERF] total=${total}ms`);

  const failed = failedFlagsFromResults(providerResults, enabled);

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
  };
}
