import type { MarketplaceListingDTO } from '../types.js';
import { fetchVintedCatalogPage } from './providers/vinted-api-search.js';
import { marketplaceListingDedupeKey } from '../lib/listing-dedupe.js';

const USE_MOCK =
  process.env.USE_MOCK?.toLowerCase() === 'true' ||
  process.env.MOCK_MODE?.toLowerCase() === 'true';

export interface SearchVintedOptions {
  /** Arrête la fusion après N annonces (premier écran rapide). */
  maxMergedListings?: number;
  /** Nombre max de requêtes texte à exécuter (défaut 2). */
  maxQueries?: number;
}

function logStart(name: string, queries: string[], opts?: SearchVintedOptions): void {
  console.log(`[PROVIDER_START] ${name}`, {
    queries,
    enabled: true,
    mock: USE_MOCK,
    opts,
  });
}

function logSuccess(name: string, count: number, durationMs: number): void {
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

export interface SearchVintedWithMeta {
  listings: MarketplaceListingDTO[];
  /** `hasMore` pour la première requête (pagination Vinted). */
  primaryHasMore: boolean;
}

/** Agrège jusqu’à `maxQueries` requêtes ; respecte `maxMergedListings` si défini. */
export async function searchVintedListingsWithMeta(
  queries: string[],
  options?: SearchVintedOptions
): Promise<SearchVintedWithMeta> {
  const maxQ = options?.maxQueries ?? 2;
  const qs = queries.map((q) => q.trim()).filter(Boolean).slice(0, maxQ);
  const cap = options?.maxMergedListings;
  logStart('vinted', qs, options);
  const t0 = performance.now();
  try {
    if (USE_MOCK) {
      const out = await mockDelayListings('vinted', 'Vinted');
      logSuccess('vinted', out.length, Math.round(performance.now() - t0));
      console.log('[RESULTS_BATCH]', { merged: out.length, mock: true });
      return { listings: out, primaryHasMore: true };
    }
    if (qs.length === 0) {
      throw new Error('vinted: empty query after trim');
    }
    const merged: MarketplaceListingDTO[] = [];
    const seen = new Set<string>();
    let primaryHasMore = false;
    let totalFetched = 0;
    outer: for (let i = 0; i < qs.length; i++) {
      const q = qs[i]!;
      const page = await fetchVintedCatalogPage(q, 1);
      console.log(
        `[VINTED_RESULTS] query=${JSON.stringify(q)} count=${page.listings.length}`
      );
      if (i === 0) primaryHasMore = page.hasMore;
      for (const L of page.listings) {
        totalFetched += 1;
        if (cap !== undefined && merged.length >= cap) break outer;
        const k = marketplaceListingDedupeKey(L);
        if (seen.has(k)) continue;
        seen.add(k);
        merged.push(L);
        if (cap !== undefined && merged.length >= cap) break outer;
      }
    }
    const ms = Math.round(performance.now() - t0);
    logSuccess('vinted', merged.length, ms);
    console.log(
      `[VINTED_MERGE] total=${totalFetched} deduped=${merged.length}`
    );
    console.log('[RESULTS_BATCH]', {
      merged: merged.length,
      queriesUsed: qs.length,
      primaryHasMore,
      capped: cap != null,
    });
    return { listings: merged, primaryHasMore };
  } catch (e) {
    logError('vinted', e);
    throw e;
  }
}

export async function searchVintedListings(
  queries: string[],
  options?: SearchVintedOptions
): Promise<MarketplaceListingDTO[]> {
  return (await searchVintedListingsWithMeta(queries, options)).listings;
}
