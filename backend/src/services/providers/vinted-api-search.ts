import type { MarketplaceListingDTO } from '../../types.js';
import { browserLikeHeaders } from '../../lib/scrape-http.js';

/**
 * Vinted — accès public catalogue (pas de jeton obligatoire).
 * En-têtes navigateur + Referer. Si VINTED_ACCESS_TOKEN est défini, Bearer ajouté (legacy).
 */
export async function fetchVintedCatalogListings(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  const base =
    process.env.VINTED_API_BASE?.trim() || 'https://www.vinted.fr/api/v2';
  const perPage = process.env.VINTED_SCRAPER_PER_PAGE?.trim() || '24';
  const path = `/catalog/items?search_text=${encodeURIComponent(
    searchText
  )}&per_page=${perPage}&page=1`;

  const token = process.env.VINTED_ACCESS_TOKEN?.trim();
  const headers: Record<string, string> = {
    ...browserLikeHeaders({
      Referer: `https://www.vinted.fr/catalog?search_text=${encodeURIComponent(searchText)}`,
      Origin: 'https://www.vinted.fr',
    }),
    Accept: 'application/json',
  };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const res = await fetch(`${base.replace(/\/$/, '')}${path}`, {
    headers,
  });

  const rawText = await res.text();
  let data: unknown;
  try {
    data = JSON.parse(rawText);
  } catch {
    throw new Error(
      `vinted scraper: non-JSON HTTP ${res.status} ${rawText.slice(0, 200)}`
    );
  }

  const root = data as Record<string, unknown>;
  if (typeof root.code === 'number' && root.code !== 0) {
    throw new Error(
      `vinted scraper: API code ${JSON.stringify({ code: root.code, message: root.message })}`
    );
  }

  const items = root.items;
  if (!Array.isArray(items)) {
    throw new Error(
      `vinted scraper: missing items[] (HTTP ${res.status}) body=${rawText.slice(0, 300)}`
    );
  }

  const out: MarketplaceListingDTO[] = [];
  for (const raw of items) {
    if (!raw || typeof raw !== 'object') continue;
    const row = raw as Record<string, unknown>;
    const id = row.id;
    const idStr =
      typeof id === 'number'
        ? String(id)
        : typeof id === 'string'
          ? id
          : undefined;
    if (!idStr) continue;

    const title =
      typeof row.title === 'string' ? row.title : `Vinted ${idStr}`;
    let price = 0;
    let currency = 'EUR';
    const p = row.price;
    if (p && typeof p === 'object' && !Array.isArray(p)) {
      const po = p as Record<string, unknown>;
      const amt = po.amount;
      if (typeof amt === 'string' || typeof amt === 'number') {
        price = Number(amt);
      }
      const cur = po.currency_code;
      if (typeof cur === 'string') currency = cur;
    }

    let photo: string | undefined;
    const photos = row.photo;
    if (photos && typeof photos === 'object' && !Array.isArray(photos)) {
      const ph = photos as Record<string, unknown>;
      const url = ph.url;
      if (typeof url === 'string') photo = url;
    }

    const urlVal = row.url;
    const listingUrl =
      typeof urlVal === 'string'
        ? urlVal.startsWith('http')
          ? urlVal
          : `https://www.vinted.fr${urlVal}`
        : `https://www.vinted.fr/items/${idStr}`;

    out.push({
      id: idStr,
      source: 'Vinted',
      title,
      price: Number.isFinite(price) ? price : 0,
      currency,
      imageUrl: photo,
      thumbnailUrl: photo,
      listingUrl,
    });
  }

  return out;
}
