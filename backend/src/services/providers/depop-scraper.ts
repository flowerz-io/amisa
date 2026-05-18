import type { MarketplaceListingDTO } from '../../types.js';
import { browserLikeHeaders } from '../../lib/scrape-http.js';

/**
 * Depop — API web publique (pas de token).
 */
export async function fetchDepopScraperListings(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  const country = process.env.DEPOP_COUNTRY?.trim() || 'fr';
  const language = process.env.DEPOP_LANGUAGE?.trim() || 'fr';
  const count = process.env.DEPOP_SCRAPER_ITEMS?.trim() || '24';

  const params = new URLSearchParams({
    what: searchText,
    items_count: count,
    country,
    language,
  });

  const url = `https://webapi.depop.com/api/v2/search/products/?${params.toString()}`;
  const res = await fetch(url, {
    headers: browserLikeHeaders({
      Referer: 'https://www.depop.com/',
      Origin: 'https://www.depop.com',
      Accept: 'application/json',
    }),
  });

  const rawText = await res.text();
  let data: unknown;
  try {
    data = JSON.parse(rawText);
  } catch {
    throw new Error(
      `depop scraper: non-JSON HTTP ${res.status} ${rawText.slice(0, 200)}`
    );
  }

  const root = data as Record<string, unknown>;
  const products = root.products ?? root.data;
  if (!Array.isArray(products)) {
    throw new Error(
      `depop scraper: no products[] HTTP ${res.status} ${rawText.slice(0, 280)}`
    );
  }

  const out: MarketplaceListingDTO[] = [];
  for (const raw of products) {
    if (!raw || typeof raw !== 'object') continue;
    const row = raw as Record<string, unknown>;
    const id = row.id ?? row.selling_id;
    const idStr =
      typeof id === 'number'
        ? String(id)
        : typeof id === 'string'
          ? id
          : undefined;
    if (!idStr) continue;

    const slug = typeof row.slug === 'string' ? row.slug : idStr;
    const description =
      typeof row.description === 'string'
        ? row.description
        : `Depop ${idStr}`;

    let price = 0;
    let currency = 'EUR';
    const pricing = row.pricing;
    if (pricing && typeof pricing === 'object' && !Array.isArray(pricing)) {
      const pr = pricing as Record<string, unknown>;
      const priceObj = pr.price;
      if (priceObj && typeof priceObj === 'object') {
        const po = priceObj as Record<string, unknown>;
        const tp = po.total_price ?? po.price;
        if (typeof tp === 'string' || typeof tp === 'number') {
          price = Number(tp);
        }
        const cur = po.currency_name ?? pr.currency;
        if (typeof cur === 'string') currency = cur.toUpperCase();
      }
    }

    let imageUrl: string | undefined;
    const pics = row.pictures;
    if (Array.isArray(pics) && pics[0] && typeof pics[0] === 'object') {
      const p0 = pics[0] as Record<string, unknown>;
      imageUrl =
        (typeof p0.url === 'string' && p0.url) ||
        (typeof p0['1280'] === 'string' && (p0['1280'] as string)) ||
        (typeof p0['640'] === 'string' && (p0['640'] as string)) ||
        undefined;
    }

    const listingUrl = `https://www.depop.com/products/${slug}/`;
    out.push({
      id: idStr,
      source: 'Depop',
      title: description.slice(0, 500),
      price: Number.isFinite(price) ? price : 0,
      currency,
      imageUrl,
      thumbnailUrl: imageUrl,
      listingUrl,
    });
  }

  return out;
}
