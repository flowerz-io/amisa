import type { MarketplaceListingDTO } from '../types.js';
import { fetchEbayBrowseListings } from './providers/ebay-browse-search.js';
import { fetchVintedCatalogListings } from './providers/vinted-api-search.js';
import { fetchDepopScraperListings } from './providers/depop-scraper.js';
import { fetchGrailedScraperListings } from './providers/grailed-scraper.js';
import { fetchLeboncoinScraperListings } from './providers/leboncoin-scraper.js';
import { marketplaceListingDedupeKey } from '../lib/listing-dedupe.js';
import { getEbayResultsLimitPerQuery } from '../lib/search-limits.js';

const USE_MOCK =
  process.env.USE_MOCK?.toLowerCase() === 'true' ||
  process.env.MOCK_MODE?.toLowerCase() === 'true';

function logStart(name: string, queries: string[]): void {
  console.log(`[PROVIDER_START] ${name}`, {
    queries,
    enabled: true,
    mock: USE_MOCK,
  });
}

function logSuccess(
  name: string,
  count: number,
  durationMs: number
): void {
  console.log(`[PROVIDER_SUCCESS] ${name}`, { count, durationMs });
}

function logError(name: string, err: unknown): void {
  console.error(`[PROVIDER_ERROR] ${name}`, err);
}

async function mockDelayListings(
  source: string,
  label: string
): Promise<MarketplaceListingDTO[]> {
  await new Promise((r) => setTimeout(r, 80));
  if (!USE_MOCK) return [];
  return [
    {
      id: `${label}-mock-1`,
      source,
      title: `[MOCK_MODE] ${label}`,
      price: 1,
      currency: 'EUR',
      listingUrl: 'https://example.com',
    },
  ];
}

/** Agrège jusqu’à 2 requêtes (aligné pipeline analyze-search). */
export async function searchVintedListings(
  queries: string[]
): Promise<MarketplaceListingDTO[]> {
  const qs = queries.map((q) => q.trim()).filter(Boolean).slice(0, 2);
  logStart('vinted', qs);
  const t0 = performance.now();
  try {
    if (USE_MOCK) {
      const out = await mockDelayListings('Vinted', 'Vinted');
      logSuccess('vinted', out.length, Math.round(performance.now() - t0));
      return out;
    }
    if (qs.length === 0) {
      throw new Error('vinted: empty query after trim');
    }
    const merged: MarketplaceListingDTO[] = [];
    const seen = new Set<string>();
    for (const q of qs) {
      for (const L of await fetchVintedCatalogListings(q)) {
        const k = marketplaceListingDedupeKey(L);
        if (seen.has(k)) continue;
        seen.add(k);
        merged.push(L);
      }
    }
    const ms = Math.round(performance.now() - t0);
    logSuccess('vinted', merged.length, ms);
    return merged;
  } catch (e) {
    logError('vinted', e);
    throw e;
  }
}

export async function searchEbayListings(
  queries: string[]
): Promise<MarketplaceListingDTO[]> {
  const qs = queries.map((q) => q.trim()).filter(Boolean).slice(0, 2);
  logStart('ebay', qs);
  const t0 = performance.now();
  try {
    if (USE_MOCK) {
      const out = await mockDelayListings('eBay', 'eBay');
      logSuccess('ebay', out.length, Math.round(performance.now() - t0));
      return out;
    }
    if (qs.length === 0) {
      throw new Error('ebay: empty query after trim');
    }
    const limitPerQuery = getEbayResultsLimitPerQuery();
    const merged: MarketplaceListingDTO[] = [];
    const seen = new Set<string>();
    const rawByQuery: number[] = [];
    let sumRaw = 0;

    for (const q of qs) {
      const batch = await fetchEbayBrowseListings(q);
      rawByQuery.push(batch.length);
      sumRaw += batch.length;
      console.log('[EBAY_QUERY_STATS]', {
        query: q,
        limitPerQuery,
        rawCount: batch.length,
      });
      for (const L of batch) {
        const k = marketplaceListingDedupeKey(L);
        if (seen.has(k)) continue;
        seen.add(k);
        merged.push(L);
      }
    }

    console.log('[EBAY_AGGREGATE]', {
      limitPerQuery,
      queryCount: qs.length,
      rawByQuery,
      sumRaw,
      afterDedup: merged.length,
    });
    const ms = Math.round(performance.now() - t0);
    logSuccess('ebay', merged.length, ms);
    return merged;
  } catch (e) {
    logError('ebay', e);
    throw e;
  }
}

export async function searchGrailedListings(
  queries: string[]
): Promise<MarketplaceListingDTO[]> {
  const qs = queries.map((q) => q.trim()).filter(Boolean).slice(0, 2);
  logStart('grailed', qs);
  const t0 = performance.now();
  try {
    if (USE_MOCK) {
      const out = await mockDelayListings('Grailed', 'Grailed');
      logSuccess('grailed', out.length, Math.round(performance.now() - t0));
      return out;
    }
    if (qs.length === 0) {
      throw new Error('grailed: empty query after trim');
    }
    const merged: MarketplaceListingDTO[] = [];
    const seen = new Set<string>();
    for (const q of qs) {
      for (const L of await fetchGrailedScraperListings(q)) {
        const k = marketplaceListingDedupeKey(L);
        if (seen.has(k)) continue;
        seen.add(k);
        merged.push(L);
      }
    }
    const ms = Math.round(performance.now() - t0);
    logSuccess('grailed', merged.length, ms);
    return merged;
  } catch (e) {
    logError('grailed', e);
    throw e;
  }
}

export async function searchDepopListings(
  queries: string[]
): Promise<MarketplaceListingDTO[]> {
  const qs = queries.map((q) => q.trim()).filter(Boolean).slice(0, 2);
  logStart('depop', qs);
  const t0 = performance.now();
  try {
    if (USE_MOCK) {
      const out = await mockDelayListings('Depop', 'Depop');
      logSuccess('depop', out.length, Math.round(performance.now() - t0));
      return out;
    }
    if (qs.length === 0) {
      throw new Error('depop: empty query after trim');
    }
    const merged: MarketplaceListingDTO[] = [];
    const seen = new Set<string>();
    for (const q of qs) {
      for (const L of await fetchDepopScraperListings(q)) {
        const k = marketplaceListingDedupeKey(L);
        if (seen.has(k)) continue;
        seen.add(k);
        merged.push(L);
      }
    }
    const ms = Math.round(performance.now() - t0);
    logSuccess('depop', merged.length, ms);
    return merged;
  } catch (e) {
    logError('depop', e);
    throw e;
  }
}

export async function searchLeboncoinListings(
  queries: string[]
): Promise<MarketplaceListingDTO[]> {
  const qs = queries.map((q) => q.trim()).filter(Boolean).slice(0, 2);
  logStart('leboncoin', qs);
  const t0 = performance.now();
  try {
    if (USE_MOCK) {
      const out = await mockDelayListings('Leboncoin', 'Leboncoin');
      logSuccess('leboncoin', out.length, Math.round(performance.now() - t0));
      return out;
    }
    if (qs.length === 0) {
      throw new Error('leboncoin: empty query after trim');
    }
    const merged: MarketplaceListingDTO[] = [];
    const seen = new Set<string>();
    for (const q of qs) {
      for (const L of await fetchLeboncoinScraperListings(q)) {
        const k = marketplaceListingDedupeKey(L);
        if (seen.has(k)) continue;
        seen.add(k);
        merged.push(L);
      }
    }
    const ms = Math.round(performance.now() - t0);
    logSuccess('leboncoin', merged.length, ms);
    return merged;
  } catch (e) {
    logError('leboncoin', e);
    throw e;
  }
}
