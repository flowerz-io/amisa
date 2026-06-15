import type { MarketplaceListingDTO } from '../../types.js';
import { fetchVintedViaBearer } from './vinted-api-bearer.js';
import { fetchVintedViaPlaywright } from './vinted-playwright.js';

const RETRY_ATTEMPTS = Number(process.env.VINTED_FETCH_RETRIES?.trim() || '2');
const RETRY_DELAY_MS = Number(process.env.VINTED_FETCH_RETRY_MS?.trim() || '800');

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

/**
 * Vinted : avec `VINTED_ACCESS_TOKEN` → API Bearer ; sinon **uniquement** Playwright.
 */
export async function fetchVintedCatalogPage(
  searchText: string,
  page: number = 1
): Promise<{ listings: MarketplaceListingDTO[]; hasMore: boolean }> {
  const token = process.env.VINTED_ACCESS_TOKEN?.trim();
  const attempts = Math.max(1, Math.min(4, Math.floor(RETRY_ATTEMPTS)));
  let lastError: unknown;
  let lastEmpty: { listings: MarketplaceListingDTO[]; hasMore: boolean } | null =
    null;

  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      const result = token
        ? await fetchVintedViaBearer(searchText, token, page)
        : await fetchVintedViaPlaywright(searchText, page);

      if (result.listings.length > 0) return result;
      lastEmpty = result;

      console.log('[VINTED_FETCH] empty_attempt', {
        attempt,
        query: searchText.slice(0, 60),
        bearer: Boolean(token),
      });

      if (attempt < attempts) await sleep(RETRY_DELAY_MS * attempt);
    } catch (e) {
      lastError = e;
      console.warn('[VINTED_FETCH] attempt_error', {
        attempt,
        query: searchText.slice(0, 60),
        err: e instanceof Error ? e.message.slice(0, 100) : String(e),
      });
      if (attempt < attempts) await sleep(RETRY_DELAY_MS * attempt);
    }
  }

  if (lastEmpty) return lastEmpty;
  if (lastError instanceof Error) throw lastError;
  throw new Error('vinted: fetch catalogue échoué après retries');
}

/** Première page uniquement (compat). */
export async function fetchVintedCatalogListings(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  const r = await fetchVintedCatalogPage(searchText, 1);
  return r.listings;
}
