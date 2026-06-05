import type { MarketplaceListingDTO } from '../../types.js';
import { browserLikeHeaders } from '../../lib/scrape-http.js';
import {
  logVintedSize,
  readSizeFromVintedRow,
  normalizeVintedSize,
} from './vinted-size-extract.js';

const DETAIL_API = 'https://www.vinted.fr/api/v2/items';

interface CacheEntry {
  size: string | null;
  fetchedAt: number;
}

const cache = new Map<string, CacheEntry>();
const CACHE_TTL_MS = 30 * 60 * 1000;

function cacheGet(itemId: string): string | null | undefined {
  const hit = cache.get(itemId);
  if (!hit) return undefined;
  if (Date.now() - hit.fetchedAt > CACHE_TTL_MS) {
    cache.delete(itemId);
    return undefined;
  }
  return hit.size;
}

function cacheSet(itemId: string, size: string | null): void {
  cache.set(itemId, { size, fetchedAt: Date.now() });
}

function bearerHeaders(): Record<string, string> | undefined {
  const token = process.env.VINTED_ACCESS_TOKEN?.trim();
  if (!token) return undefined;
  return browserLikeHeaders({
    Authorization: `Bearer ${token}`,
    Accept: 'application/json',
  });
}

/** Ex. « 37 · Neuf sans étiquette » ou « M · Très bon état ». */
const DETAIL_HTML_SIZE_RE =
  /(?:^|[\s>"])(XXXL|XXL|XL|L|M|S|XS|XXS|OS|TU|(?:3[5-9]|4[0-8])(?:\s*[12]\s*\/\s*[23]|[.,][05])?)\s*(?:·|&middot;|&#183;)/i;

const JSON_LD_SIZE_RE =
  /"size"\s*:\s*"([^"]+)"/i;

function extractSizeFromDetailHtml(html: string): string | null {
  const htmlHit = html.match(DETAIL_HTML_SIZE_RE);
  if (htmlHit) {
    const normalized = normalizeVintedSize(htmlHit[1]);
    if (normalized) return normalized;
  }

  const ldHit = html.match(JSON_LD_SIZE_RE);
  if (ldHit) {
    const normalized = normalizeVintedSize(ldHit[1]);
    if (normalized) return normalized;
  }

  const pluginSize = html.match(
    /"size_title"\s*:\s*"([^"]+)"/i
  );
  if (pluginSize) {
    const normalized = normalizeVintedSize(pluginSize[1]);
    if (normalized) return normalized;
  }

  return null;
}

async function fetchDetailJson(
  itemId: string
): Promise<Record<string, unknown> | null> {
  const url = `${DETAIL_API}/${itemId}`;
  const headers = bearerHeaders() ?? browserLikeHeaders({ Accept: 'application/json' });
  try {
    const res = await fetch(url, { headers });
    if (!res.ok) return null;
    const data = (await res.json()) as Record<string, unknown>;
    const item = data.item;
    if (item && typeof item === 'object' && !Array.isArray(item)) {
      return item as Record<string, unknown>;
    }
    return null;
  } catch {
    return null;
  }
}

async function fetchDetailHtml(
  listingUrl: string
): Promise<string | null> {
  try {
    const res = await fetch(listingUrl, {
      headers: browserLikeHeaders({ Accept: 'text/html' }),
    });
    if (!res.ok) return null;
    return await res.text();
  } catch {
    return null;
  }
}

/**
 * Récupère la taille depuis la page détail Vinted (API v2 puis HTML).
 * Résultat mis en cache par `itemId`.
 */
export async function fetchVintedItemSizeFromDetail(
  itemId: string,
  listingUrl?: string,
  title?: string
): Promise<string | null> {
  const cached = cacheGet(itemId);
  if (cached !== undefined) return cached;

  const item = await fetchDetailJson(itemId);
  if (item) {
    const fromApi = readSizeFromVintedRow(item);
    if (fromApi) {
      cacheSet(itemId, fromApi);
      if (title) logVintedSize(title, 'detail', fromApi);
      return fromApi;
    }
  }

  const url =
    listingUrl?.trim() ||
    `https://www.vinted.fr/items/${itemId}`;
  const html = await fetchDetailHtml(url);
  if (html) {
    const fromHtml = extractSizeFromDetailHtml(html);
    cacheSet(itemId, fromHtml);
    if (fromHtml && title) {
      logVintedSize(title, 'detail', fromHtml);
    }
    return fromHtml;
  }

  cacheSet(itemId, null);
  return null;
}

export interface EnrichDetailSizesOptions {
  /** Nombre max d’annonces sans taille à enrichir (défaut 12). */
  limit?: number;
  /** Requêtes détail en parallèle (défaut 4). */
  concurrency?: number;
}

async function mapWithConcurrency<T, R>(
  items: T[],
  concurrency: number,
  fn: (item: T) => Promise<R>
): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let idx = 0;
  async function worker(): Promise<void> {
    while (idx < items.length) {
      const i = idx++;
      out[i] = await fn(items[i]!);
    }
  }
  const workers = Array.from(
    { length: Math.min(concurrency, items.length) },
    () => worker()
  );
  await Promise.all(workers);
  return out;
}

/**
 * Enrichit les premières annonces Vinted sans taille via fetch page détail.
 */
export async function enrichVintedListingsWithDetailSizes(
  listings: MarketplaceListingDTO[],
  options?: EnrichDetailSizesOptions
): Promise<MarketplaceListingDTO[]> {
  const limit = options?.limit ?? 12;
  const concurrency = options?.concurrency ?? 4;

  const needsEnrich: { index: number; listing: MarketplaceListingDTO }[] = [];
  for (let i = 0; i < listings.length && needsEnrich.length < limit; i++) {
    const L = listings[i]!;
    if (L.source !== 'vinted') continue;
    if (L.size != null && L.size.trim() !== '') continue;
    needsEnrich.push({ index: i, listing: L });
  }

  if (needsEnrich.length === 0) return listings;

  const sizes = await mapWithConcurrency(
    needsEnrich,
    concurrency,
    async ({ listing }) =>
      fetchVintedItemSizeFromDetail(
        listing.id,
        listing.listingUrl,
        listing.title
      )
  );

  const out = [...listings];
  for (let j = 0; j < needsEnrich.length; j++) {
    const size = sizes[j];
    if (!size) continue;
    const { index, listing } = needsEnrich[j]!;
    out[index] = { ...listing, size };
  }

  return out;
}
