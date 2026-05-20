import type { MarketplaceListingDTO } from '../../types.js';
import { fetchVintedViaBearer } from './vinted-api-bearer.js';
import { fetchVintedViaPlaywright } from './vinted-playwright.js';

/**
 * Vinted : avec `VINTED_ACCESS_TOKEN` → API Bearer ; sinon **uniquement** Playwright (aucun fetch serveur sans jeton).
 */
export async function fetchVintedCatalogPage(
  searchText: string,
  page: number = 1
): Promise<{ listings: MarketplaceListingDTO[]; hasMore: boolean }> {
  const token = process.env.VINTED_ACCESS_TOKEN?.trim();
  if (token) {
    return fetchVintedViaBearer(searchText, token, page);
  }
  return fetchVintedViaPlaywright(searchText, page);
}

/** Première page uniquement (compat). */
export async function fetchVintedCatalogListings(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  const r = await fetchVintedCatalogPage(searchText, 1);
  return r.listings;
}
