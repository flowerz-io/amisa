import type {
  AnalyzeSearchBody,
  AnalyzeSearchResponseJSON,
  MarketplaceListingDTO,
} from '../types.js';
import { analyzeFashionVision } from './vision-openai.js';
import { buildPrimaryQueries } from '../lib/query-from-vision.js';
import {
  failedFlagsFromResults,
  mergeAndCapListings,
  PROVIDER_TIMEOUT_MS,
  runProvidersWithEarlyCutoff,
  type ProviderName,
} from '../lib/parallel-providers.js';
import {
  searchDepopStub,
  searchEbayStub,
  searchGrailedStub,
  searchLeboncoinStub,
  searchVintedStub,
} from './marketplace-stubs.js';

const GLOBAL_WAIT_MS = 15_000;
const MIN_PROVIDERS_DONE = 2;

async function runQueriesOnProvider(
  fn: (queries: string[]) => Promise<MarketplaceListingDTO[]>,
  queries: string[]
): Promise<MarketplaceListingDTO[]> {
  const all: MarketplaceListingDTO[] = [];
  for (const q of queries) {
    const chunk = await fn([q]);
    all.push(...chunk);
  }
  return all;
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

  const tasks: Array<{
    name: ProviderName;
    timeoutMs: number;
    run: () => Promise<MarketplaceListingDTO[]>;
  }> = [];

  if (enabled.has('vinted')) {
    tasks.push({
      name: 'vinted',
      timeoutMs: PROVIDER_TIMEOUT_MS.vinted,
      run: () => runQueriesOnProvider(searchVintedStub, queries),
    });
  }
  if (enabled.has('ebay')) {
    tasks.push({
      name: 'ebay',
      timeoutMs: PROVIDER_TIMEOUT_MS.ebay,
      run: () => runQueriesOnProvider(searchEbayStub, queries),
    });
  }
  if (enabled.has('grailed')) {
    tasks.push({
      name: 'grailed',
      timeoutMs: PROVIDER_TIMEOUT_MS.grailed,
      run: () => runQueriesOnProvider(searchGrailedStub, queries),
    });
  }
  if (enabled.has('depop')) {
    tasks.push({
      name: 'depop',
      timeoutMs: PROVIDER_TIMEOUT_MS.depop,
      run: () => runQueriesOnProvider(searchDepopStub, queries),
    });
  }
  if (enabled.has('leboncoin')) {
    tasks.push({
      name: 'leboncoin',
      timeoutMs: PROVIDER_TIMEOUT_MS.leboncoin,
      run: () => runQueriesOnProvider(searchLeboncoinStub, queries),
    });
  }

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
