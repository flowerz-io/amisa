import type { MarketplaceListingDTO } from '../../types.js';
import { browserLikeHeaders } from '../../lib/scrape-http.js';
import { parseVintedCatalogPayload } from './vinted-catalog-parse.js';

/** Appel API Vinted **uniquement** avec Bearer (session mobile capturée). */
export async function fetchVintedViaBearer(
  searchText: string,
  token: string
): Promise<MarketplaceListingDTO[]> {
  const base =
    process.env.VINTED_API_BASE?.trim() || 'https://www.vinted.fr/api/v2';
  const perPage = process.env.VINTED_SCRAPER_PER_PAGE?.trim() || '24';
  const path = `/catalog/items?search_text=${encodeURIComponent(
    searchText
  )}&per_page=${perPage}&page=1`;

  const res = await fetch(`${base.replace(/\/$/, '')}${path}`, {
    headers: {
      ...browserLikeHeaders({
        Referer: `https://www.vinted.fr/catalog?search_text=${encodeURIComponent(searchText)}`,
        Origin: 'https://www.vinted.fr',
      }),
      Accept: 'application/json',
      Authorization: `Bearer ${token}`,
    },
  });

  const rawText = await res.text();
  let data: unknown;
  try {
    data = JSON.parse(rawText);
  } catch {
    throw new Error(
      `vinted api: réponse non-JSON HTTP ${res.status} ${rawText.slice(0, 200)}`
    );
  }

  return parseVintedCatalogPayload(data, res.status);
}
