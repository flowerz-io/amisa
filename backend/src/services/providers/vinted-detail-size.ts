import type { MarketplaceListingDTO } from '../../types.js';
import { browserLikeHeaders } from '../../lib/scrape-http.js';
import {
  launchChromiumHeadless,
  PLAYWRIGHT_UA,
} from '../../lib/playwright-browser.js';
import {
  extractSizeFromDescription,
  extractSizeFromDetailHeaderLine,
  extractSizeFromTitle,
  logVintedSize,
  needsVintedSizeEnrichment,
  normalizeVintedSize,
  readSizeFromVintedRow,
} from './vinted-size-extract.js';

const DETAIL_API = 'https://www.vinted.fr/api/v2/items';
const DEFAULT_ENRICH_WINDOW = 25;
const DEFAULT_CONCURRENCY = 5;

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

/** Extrait la taille depuis le HTML statique (JSON embarqué ou motif ·). */
export function extractSizeFromDetailHtml(html: string): string | null {
  const sizeTitleMatches = [
    ...html.matchAll(/"size_title"\s*:\s*"([^"\\]+)"/gi),
    ...html.matchAll(/size_title\\":\\"([^"\\]+)\\"/gi),
  ];
  for (const m of sizeTitleMatches) {
    const normalized = normalizeVintedSize(m[1] ?? '');
    if (normalized) return normalized;
  }

  const attrSize = html.match(
    /data-testid="item-attributes-size"[^>]*>[\s\S]*?Taille\s*([^<]+)</i
  );
  if (attrSize?.[1]) {
    const normalized = normalizeVintedSize(attrSize[1].trim());
    if (normalized) return normalized;
  }

  const dotMatches = html.matchAll(
    /(?:^|[\s>"'])(XXXL|XXL|XL|L|M|S|XS|XXS|(?:3[5-9]|4[0-8])(?:\s*[12]\s*\/\s*[23])?)\s*(?:·|&middot;|&#183;|•)/gi
  );
  for (const m of dotMatches) {
    const normalized = normalizeVintedSize(m[1] ?? '');
    if (normalized) return normalized;
  }

  return null;
}

/** Script exécuté dans le navigateur Playwright sur une page détail Vinted. */
const DETAIL_PAGE_EXTRACT_SCRIPT = `
(() => {
  const normalize = (raw) => {
    const t = (raw || '').trim();
    if (!t) return null;
    const frac = t.match(/\\b(3[5-9]|4[0-8])\\s*([12])\\s*\\/\\s*([23])\\b/);
    if (frac) return frac[1] + ' ' + frac[2] + '/' + frac[3];
    const dec = t.match(/\\b(3[5-9]|4[0-8])[.,]([05])\\b/);
    if (dec) return dec[1] + '.' + dec[2];
    const cloth = t.match(/\\b(XXXL|XXL|XL|L|M|S|XS|XXS|OS)\\b/i);
    if (cloth) return cloth[1].toUpperCase();
    const shoe = t.match(/^(3[5-9]|4[0-8])$/);
    if (shoe) return shoe[1];
    return null;
  };

  const sizeEl = document.querySelector('[data-testid="item-attributes-size"]');
  if (sizeEl) {
    const label = (sizeEl.textContent || '').replace(/^Taille\\s*/i, '').trim();
    const n = normalize(label);
    if (n) return n;
    if (label) return label;
  }

  const lines = (document.body.innerText || '').split('\\n').map((l) => l.trim()).filter(Boolean);
  for (const line of lines) {
    if (!line.includes('·') && !line.includes('•')) continue;
    const m = line.match(/^(XXXL|XXL|XL|L|M|S|XS|XXS|OS|TU|(3[5-9]|4[0-8])(?:\\s*[12]\\s*\\/\\s*[23])?)\\s*(?:·|•)/i);
    if (m) {
      const n = normalize(m[1]);
      if (n) return n;
    }
  }

  const descPatterns = [
    /pointure\\s*:?\\s*(3[5-9]|4[0-8])(?:\\s*[12]\\s*\\/\\s*[23]|[.,][05])?/i,
    /taille\\s*:?\\s*(3[5-9]|4[0-8])(?:\\s*[12]\\s*\\/\\s*[23]|[.,][05])?/i,
    /\\bsize\\s*:?\\s*(3[5-9]|4[0-8])(?:\\s*[12]\\s*\\/\\s*[23]|[.,][05])?/i,
    /\\bnum\\.?\\s*(3[5-9]|4[0-8])(?:\\s*[12]\\s*\\/\\s*[23]|[.,][05])?/i,
    /\\b(3[5-9]|4[0-8])\\s*([12])\\s*\\/\\s*([23])\\b/,
    /\\b(XXXL|XXL|XL|L|M|S|XS|XXS)\\b/,
  ];
  const body = document.body.innerText || '';
  for (const p of descPatterns) {
    const hit = body.match(p);
    if (!hit) continue;
    if (hit[2] && hit[3]) return hit[1] + ' ' + hit[2] + '/' + hit[3];
    const n = normalize(hit[1]);
    if (n) return n;
  }

  return null;
})()
`;

async function fetchDetailJson(
  itemId: string
): Promise<Record<string, unknown> | null> {
  const headers = bearerHeaders();
  if (!headers) return null;

  const url = `${DETAIL_API}/${itemId}`;
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

async function fetchDetailHtmlPlain(
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

async function tryFastDetailFetch(
  itemId: string,
  listingUrl: string
): Promise<string | null> {
  const cached = cacheGet(itemId);
  if (cached !== undefined) return cached;

  const item = await fetchDetailJson(itemId);
  if (item) {
    let size = readSizeFromVintedRow(item);
    if (!size && typeof item.description === 'string') {
      size = extractSizeFromDescription(item.description);
    }
    if (size) {
      cacheSet(itemId, size);
      return size;
    }
  }

  const html = await fetchDetailHtmlPlain(listingUrl);
  if (html) {
    const fromHtml = extractSizeFromDetailHtml(html);
    if (fromHtml) {
      cacheSet(itemId, fromHtml);
      return fromHtml;
    }
    const textLines = html
      .replace(/<[^>]+>/g, '\n')
      .split('\n')
      .map((l) => l.trim())
      .filter(Boolean);
    for (const line of textLines) {
      const header = extractSizeFromDetailHeaderLine(line);
      if (header) {
        cacheSet(itemId, header);
        return header;
      }
    }
  }

  return null;
}

async function fetchSizesViaPlaywright(
  items: { itemId: string; listingUrl: string }[],
  concurrency: number
): Promise<Map<string, string | null>> {
  const out = new Map<string, string | null>();
  if (items.length === 0) return out;

  const browser = await launchChromiumHeadless();
  try {
    const ctx = await browser.newContext({
      userAgent: PLAYWRIGHT_UA,
      locale: 'fr-FR',
      timezoneId: 'Europe/Paris',
      viewport: { width: 1280, height: 900 },
    });

    let cursor = 0;
    async function worker(): Promise<void> {
      while (cursor < items.length) {
        const i = cursor++;
        const { itemId, listingUrl } = items[i]!;
        const page = await ctx.newPage();
        try {
          await page.goto(listingUrl, {
            waitUntil: 'domcontentloaded',
            timeout: 45000,
          });
          await page.waitForTimeout(1500);
          const raw = await page.evaluate(DETAIL_PAGE_EXTRACT_SCRIPT);
          const size =
            typeof raw === 'string' && raw.trim()
              ? normalizeVintedSize(raw) ?? raw.trim()
              : null;
          out.set(itemId, size);
          cacheSet(itemId, size);
        } catch (e) {
          console.warn('[VINTED_DETAIL_FETCH_ERROR]', { itemId, err: e });
          out.set(itemId, null);
          cacheSet(itemId, null);
        } finally {
          await page.close();
        }
      }
    }

    const workers = Array.from(
      { length: Math.min(concurrency, items.length) },
      () => worker()
    );
    await Promise.all(workers);
  } finally {
    await browser.close();
  }

  return out;
}

function listingUrlFor(L: MarketplaceListingDTO): string {
  return L.listingUrl?.trim() || `https://www.vinted.fr/items/${L.id}`;
}

function inferListSource(listing: MarketplaceListingDTO): 'list' | 'title' {
  const fromTitle = extractSizeFromTitle(listing.title);
  if (fromTitle && listing.size === fromTitle) return 'title';
  return 'list';
}

export interface EnrichDetailSizesOptions {
  /** Fenêtre des premiers résultats à considérer (défaut 25). */
  window?: number;
  /** Requêtes détail en parallèle (défaut 5). */
  concurrency?: number;
}

/**
 * Enrichit les premières annonces Vinted sans taille via fetch page détail (Playwright).
 */
export async function enrichVintedListingsWithDetailSizes(
  listings: MarketplaceListingDTO[],
  options?: EnrichDetailSizesOptions
): Promise<MarketplaceListingDTO[]> {
  const windowSize =
    options?.window ??
    Number(
      process.env.VINTED_DETAIL_SIZE_ENRICH_LIMIT?.trim() ||
        String(DEFAULT_ENRICH_WINDOW)
    );
  const concurrency =
    options?.concurrency ??
    Number(
      process.env.VINTED_DETAIL_SIZE_CONCURRENCY?.trim() ||
        String(DEFAULT_CONCURRENCY)
    );

  const safeWindow =
    Number.isFinite(windowSize) && windowSize > 0
      ? Math.floor(windowSize)
      : DEFAULT_ENRICH_WINDOW;
  const safeConcurrency =
    Number.isFinite(concurrency) && concurrency > 0
      ? Math.floor(concurrency)
      : DEFAULT_CONCURRENCY;

  const limit = Math.min(listings.length, safeWindow);
  const needsEnrich: { index: number; listing: MarketplaceListingDTO }[] = [];

  for (let i = 0; i < limit; i++) {
    const L = listings[i]!;
    if (L.source !== 'vinted') continue;
    if (!needsVintedSizeEnrichment(L.size)) continue;
    needsEnrich.push({ index: i, listing: L });
  }

  const fastResults = new Map<string, string | null>();
  const playwrightQueue: { itemId: string; listingUrl: string }[] = [];

  await Promise.all(
    needsEnrich.map(async ({ listing }) => {
      const url = listingUrlFor(listing);
      const fast = await tryFastDetailFetch(listing.id, url);
      if (fast) {
        fastResults.set(listing.id, fast);
      } else {
        playwrightQueue.push({ itemId: listing.id, listingUrl: url });
      }
    })
  );

  const playwrightResults =
    playwrightQueue.length > 0
      ? await fetchSizesViaPlaywright(playwrightQueue, safeConcurrency)
      : new Map<string, string | null>();

  const out = listings.map((L) => ({ ...L, size: L.size ?? null }));

  for (const { index, listing } of needsEnrich) {
    const extracted =
      fastResults.get(listing.id) ??
      playwrightResults.get(listing.id) ??
      null;

    if (extracted) {
      out[index] = { ...listing, size: extracted };
      logVintedSize(
        listing.title,
        'detail',
        extracted,
        listingUrlFor(listing)
      );
    } else {
      logVintedSize(
        listing.title,
        'none',
        null,
        listingUrlFor(listing)
      );
    }
  }

  for (let i = 0; i < limit; i++) {
    const L = out[i];
    if (!L || L.source !== 'vinted') continue;
    if (needsEnrich.some((n) => n.index === i)) continue;
    if (L.size) {
      logVintedSize(
        L.title,
        inferListSource(L),
        L.size,
        listingUrlFor(L)
      );
    } else {
      logVintedSize(L.title, 'none', null, listingUrlFor(L));
    }
  }

  return out;
}

/** Compat : fetch unitaire (utilise cache + Playwright si nécessaire). */
export async function fetchVintedItemSizeFromDetail(
  itemId: string,
  listingUrl?: string
): Promise<string | null> {
  const url = listingUrl?.trim() || `https://www.vinted.fr/items/${itemId}`;
  const fast = await tryFastDetailFetch(itemId, url);
  if (fast) return fast;
  const pw = await fetchSizesViaPlaywright([{ itemId, listingUrl: url }], 1);
  return pw.get(itemId) ?? null;
}
