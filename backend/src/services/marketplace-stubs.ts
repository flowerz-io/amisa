import type { MarketplaceListingDTO } from '../types.js';

/**
 * Branche ici tes scrapers Playwright / HTTP réels (Railway).
 * Par défaut : résolution rapide pour valider le pipeline et les timeouts.
 */
export async function searchVintedStub(
  queries: string[]
): Promise<MarketplaceListingDTO[]> {
  void queries;
  return [];
}

export async function searchEbayStub(
  queries: string[]
): Promise<MarketplaceListingDTO[]> {
  void queries;
  return [];
}

export async function searchGrailedStub(
  queries: string[]
): Promise<MarketplaceListingDTO[]> {
  void queries;
  return [];
}

export async function searchDepopStub(
  queries: string[]
): Promise<MarketplaceListingDTO[]> {
  void queries;
  return [];
}

export async function searchLeboncoinStub(
  queries: string[]
): Promise<MarketplaceListingDTO[]> {
  void queries;
  return [];
}
