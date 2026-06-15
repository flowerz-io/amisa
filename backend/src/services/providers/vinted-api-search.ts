import type { MarketplaceListingDTO } from '../../types.js';
import { ProviderScrapeError } from '../../lib/provider-scrape-error.js';
import { fetchVintedViaBearer } from './vinted-api-bearer.js';
import { fetchVintedViaPlaywright } from './vinted-playwright.js';

/**
 * Vinted : avec `VINTED_ACCESS_TOKEN` → API Bearer ; sinon Playwright.
 * Blocage 403 / DataDome → échec immédiat (pas de retry).
 */
export async function fetchVintedCatalogPage(
  searchText: string,
  page: number = 1
): Promise<{ listings: MarketplaceListingDTO[]; hasMore: boolean }> {
  const token = process.env.VINTED_ACCESS_TOKEN?.trim();
  try {
    return token
      ? await fetchVintedViaBearer(searchText, token, page)
      : await fetchVintedViaPlaywright(searchText, page);
  } catch (e) {
    if (e instanceof ProviderScrapeError && e.blocked403) {
      console.log('[PROVIDER_BLOCKED]', {
        provider: 'vinted',
        reason: e.message.slice(0, 120),
      });
      console.log('[PROVIDER_FAST_FAIL]', { provider: 'vinted', attempt: 1 });
    }
    throw e;
  }
}

/** Première page uniquement (compat). */
export async function fetchVintedCatalogListings(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  const r = await fetchVintedCatalogPage(searchText, 1);
  return r.listings;
}
