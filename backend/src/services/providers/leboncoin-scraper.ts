import type { MarketplaceListingDTO } from '../../types.js';
import { ProviderScrapeError } from '../../lib/provider-scrape-error.js';
import { fetchHtmlViaPlaywright } from '../../lib/playwright-browser.js';

function extractNextDataJson(html: string): unknown | null {
  const m = html.match(
    /<script id="__NEXT_DATA__" type="application\/json">([^<]+)<\/script>/
  );
  if (!m?.[1]) return null;
  try {
    return JSON.parse(m[1]);
  } catch {
    return null;
  }
}

function findAdArrays(v: unknown, depth = 0): Record<string, unknown>[][] {
  if (depth > 28) return [];
  if (!v || typeof v !== 'object') return [];
  if (Array.isArray(v)) {
    if (
      v.length > 0 &&
      typeof v[0] === 'object' &&
      v[0] !== null &&
      ('list_id' in (v[0] as object) || 'adview_id' in (v[0] as object))
    ) {
      return [v as Record<string, unknown>[]];
    }
    return v.flatMap((x) => findAdArrays(x, depth + 1));
  }
  const o = v as Record<string, unknown>;
  if (Array.isArray(o.ads)) {
    return findAdArrays(o.ads, depth + 1);
  }
  return Object.values(o).flatMap((x) => findAdArrays(x, depth + 1));
}

/**
 * Leboncoin — page recherche + __NEXT_DATA__ (pas de token API).
 */
export async function fetchLeboncoinScraperListings(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  const url = `https://www.leboncoin.fr/recherche?text=${encodeURIComponent(
    searchText
  )}&category=9`;
  const { status, html } = await fetchHtmlViaPlaywright(url, {
    referer: 'https://www.leboncoin.fr/',
  });

  if (status === 403) {
    throw new ProviderScrapeError(
      'leboncoin: HTTP 403 (origine / bot)',
      403,
      true
    );
  }

  if (
    html.includes('cf-browser-verification') ||
    html.includes('Just a moment') ||
    html.includes('challenge-platform')
  ) {
    throw new ProviderScrapeError(
      'leboncoin: page protégée Cloudflare',
      403,
      true
    );
  }

  if (!html || status >= 400) {
    throw new Error(`leboncoin scraper: HTTP ${status}`);
  }

  const next = extractNextDataJson(html);
  if (!next) {
    throw new Error(
      'leboncoin scraper: __NEXT_DATA__ introuvable (captcha / HTML changé)'
    );
  }

  const adGroups = findAdArrays(next);
  const flat = adGroups.length ? adGroups[0]! : [];

  const out: MarketplaceListingDTO[] = [];
  const seen = new Set<string>();

  for (const row of flat) {
    const listId = row.list_id ?? row.adview_id ?? row.id;
    const idStr =
      typeof listId === 'string'
        ? listId
        : typeof listId === 'number'
          ? String(listId)
          : null;
    if (!idStr) continue;

    const subject =
      typeof row.subject === 'string'
        ? row.subject
        : typeof row.title === 'string'
          ? row.title
          : `Leboncoin ${idStr}`;

    let price = 0;
    const pr = row.price;
    if (pr && typeof pr === 'object' && !Array.isArray(pr)) {
      const p = pr as Record<string, unknown>;
      const arr = p.price_array;
      if (Array.isArray(arr) && arr[0] && typeof arr[0] === 'object') {
        const p0 = arr[0] as Record<string, unknown>;
        if (typeof p0.price === 'number') price = p0.price;
        if (typeof p0.price === 'string') price = Number(p0.price);
      }
    }

    let imageUrl: string | undefined;
    const img = row.images;
    if (img && typeof img === 'object' && !Array.isArray(img)) {
      const urls = (img as Record<string, unknown>).thumb_url;
      if (typeof urls === 'string') imageUrl = urls;
    }

    const urlRaw = row.url;
    const listingUrl =
      typeof urlRaw === 'string'
        ? urlRaw.startsWith('http')
          ? urlRaw
          : `https://www.leboncoin.fr${urlRaw}`
        : `https://www.leboncoin.fr/ad/reply/${idStr}`;

    const k = listingUrl;
    if (seen.has(k)) continue;
    seen.add(k);

    out.push({
      id: idStr,
      source: 'Leboncoin',
      title: subject.slice(0, 500),
      price: Number.isFinite(price) ? price : 0,
      currency: 'EUR',
      imageUrl,
      thumbnailUrl: imageUrl,
      listingUrl,
    });
    if (out.length >= 35) break;
  }

  if (out.length === 0) {
    throw new Error(
      'leboncoin scraper: aucune annonce extraite (sélecteurs ou anti-bot)'
    );
  }
  return out;
}
