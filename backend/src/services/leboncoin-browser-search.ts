import { chromium } from 'playwright';
import type { Browser, BrowserContext, Page } from 'playwright';
import * as cheerio from 'cheerio';
import { LEBONCOIN_MAX_PER_PAGE } from '../marketplace-limits.js';

const LEBONCOIN_ORIGIN = 'https://www.leboncoin.fr';

export type LeBonCoinSearchItem = {
  source: 'Le Bon Coin';
  sourceKey: 'leboncoin';
  title: string;
  price?: number;
  currency?: string;
  imageUrl?: string;
  thumbnailUrl?: string;
  listingUrl: string;
  brand?: string;
  size?: string;
  condition?: string;
  location?: string;
  category?: string;
};

export type LeBonCoinSearchOptions = {
  page?: number;
  limit?: number;
};

export type LeBonCoinSearchResult = {
  items: LeBonCoinSearchItem[];
  totalCount?: number;
};

function encodeLeboncoinText(input: string): string {
  return encodeURIComponent(input.trim()).replace(/%20/g, '+');
}

export function buildLeBonCoinSearchUrl(query: string, page: number = 1): string {
  const text = encodeLeboncoinText(query);
  const base = `${LEBONCOIN_ORIGIN}/recherche?text=${text}`;
  if (page <= 1) return base;
  return `${base}&page=${page}`;
}

function toAbsoluteUrl(href: string): string {
  const t = href.trim();
  if (!t) return '';
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  if (t.startsWith('//')) return `https:${t}`;
  return `${LEBONCOIN_ORIGIN}${t.startsWith('/') ? '' : '/'}${t}`;
}

function parsePrice(raw: string): { price?: number; currency?: string } {
  const text = (raw ?? '').replace(/\u00a0/g, ' ').trim();
  if (!text) return {};
  const currency = text.includes('€') ? 'EUR' : text.includes('$') ? 'USD' : 'EUR';
  const num = text.replace(/[^\d,.-]/g, '').replace(/\s/g, '');
  if (!num) return { currency };
  const normalized =
    num.includes(',') && !num.includes('.') ? num.replace(/\./g, '').replace(',', '.') : num.replace(/,/g, '');
  const n = parseFloat(normalized);
  if (!Number.isFinite(n)) return { currency };
  return { price: n, currency };
}

function parsePriceCents(cents: unknown): { price?: number; currency?: string } {
  if (typeof cents !== 'number' || !Number.isFinite(cents)) return {};
  return { price: cents / 100, currency: 'EUR' };
}

function extractFirstImage(images: unknown): string | undefined {
  if (!images || typeof images !== 'object') return undefined;
  const obj = images as Record<string, unknown>;
  const thumb = typeof obj.thumb_url === 'string' ? obj.thumb_url.trim() : '';
  if (thumb) return thumb;
  if (Array.isArray(obj.urls)) {
    const first = obj.urls.find((x) => typeof x === 'string' && x.trim().length > 0) as string | undefined;
    if (first) return first.trim();
  }
  return undefined;
}

function extractTotalCountFromText(text: string): number | undefined {
  const normalized = text.replace(/\u00a0/g, ' ');
  const m = normalized.match(/(\d[\d\s]*)\s+annonces/i);
  if (!m) return undefined;
  const n = parseInt(m[1].replace(/\s/g, ''), 10);
  return Number.isFinite(n) ? n : undefined;
}

function extractTotalCount($: cheerio.CheerioAPI): number | undefined {
  const headline =
    $('[data-test-id*="result"]')
      .first()
      .text()
      .trim() || '';
  const fromHeadline = extractTotalCountFromText(headline);
  if (fromHeadline !== undefined) return fromHeadline;
  return extractTotalCountFromText($.root().text().slice(0, 8000));
}

function normalizeMaybeString(v: unknown): string | undefined {
  if (typeof v !== 'string') return undefined;
  const t = v.trim();
  return t.length > 0 ? t : undefined;
}

function extractAttributes(attrs: unknown): { brand?: string; size?: string; condition?: string } {
  if (!Array.isArray(attrs)) return {};
  let brand: string | undefined;
  let size: string | undefined;
  let condition: string | undefined;
  for (const entry of attrs) {
    if (!entry || typeof entry !== 'object') continue;
    const obj = entry as Record<string, unknown>;
    const key = String(obj.key ?? obj.name ?? '').toLowerCase();
    const value = normalizeMaybeString(obj.value ?? obj.value_label ?? obj.label);
    if (!value) continue;
    if (!brand && (key.includes('marque') || key === 'brand')) brand = value;
    if (!size && (key.includes('taille') || key === 'size')) size = value;
    if (!condition && (key.includes('etat') || key.includes('condition'))) condition = value;
  }
  return { brand, size, condition };
}

function looksLikeAdCandidate(obj: Record<string, unknown>): boolean {
  const hasUrl = typeof obj.url === 'string' || typeof obj.listing_url === 'string';
  const hasTitle =
    typeof obj.subject === 'string' || typeof obj.title === 'string' || typeof obj.name === 'string';
  return hasUrl && hasTitle;
}

function collectCandidateObjects(root: unknown, out: Record<string, unknown>[]): void {
  if (!root) return;
  if (Array.isArray(root)) {
    for (const x of root) collectCandidateObjects(x, out);
    return;
  }
  if (typeof root !== 'object') return;
  const obj = root as Record<string, unknown>;
  if (looksLikeAdCandidate(obj)) out.push(obj);
  for (const value of Object.values(obj)) collectCandidateObjects(value, out);
}

function extractFromStructuredData($: cheerio.CheerioAPI, limit: number): LeBonCoinSearchItem[] {
  const candidates: Record<string, unknown>[] = [];
  $('script[type="application/ld+json"], script').each((_i, el) => {
    const raw = $(el).html()?.trim() ?? '';
    if (!raw) return;
    if (!raw.includes('subject') && !raw.includes('price_cents') && !raw.includes('category_name')) return;
    try {
      const parsed = JSON.parse(raw);
      collectCandidateObjects(parsed, candidates);
    } catch {
      // ignore malformed blocks
    }
  });

  const seen = new Set<string>();
  const items: LeBonCoinSearchItem[] = [];
  for (const obj of candidates) {
    if (items.length >= limit) break;
    const title = normalizeMaybeString(obj.subject ?? obj.title ?? obj.name);
    const href = normalizeMaybeString(obj.url ?? obj.listing_url);
    if (!title || !href) continue;

    const listingUrl = toAbsoluteUrl(href);
    if (!listingUrl || seen.has(listingUrl)) continue;
    seen.add(listingUrl);

    const fromCents = parsePriceCents(obj.price_cents);
    const fromText = parsePrice(String(obj.price ?? ''));
    const price = fromCents.price ?? fromText.price;
    const currency = fromCents.currency ?? fromText.currency ?? 'EUR';
    const image =
      normalizeMaybeString(obj.image_url) ||
      extractFirstImage(obj.images) ||
      normalizeMaybeString(obj.image);
    const { brand, size, condition } = extractAttributes(obj.attributes);
    const location =
      normalizeMaybeString(obj.location_name) ||
      normalizeMaybeString((obj.location as Record<string, unknown> | undefined)?.city_label);
    const category = normalizeMaybeString(obj.category_name);

    items.push({
      source: 'Le Bon Coin',
      sourceKey: 'leboncoin',
      title,
      ...(price !== undefined ? { price } : {}),
      currency,
      ...(image ? { imageUrl: image, thumbnailUrl: image } : {}),
      listingUrl,
      ...(brand ? { brand } : {}),
      ...(size ? { size } : {}),
      ...(condition ? { condition } : {}),
      ...(location ? { location } : {}),
      ...(category ? { category } : {}),
    });
  }
  return items;
}

function pickImageFromCard($root: cheerio.Cheerio<any>): string | undefined {
  const src =
    $root.find('[data-test-id="adcard-image"] img').first().attr('src')?.trim() ||
    $root.find('[data-test-id="adcard-image"] img').first().attr('data-src')?.trim() ||
    $root.find('[data-test-id="adcard-image"] source').first().attr('srcset')?.split(' ')[0]?.trim() ||
    $root.find('img').first().attr('src')?.trim();
  return src || undefined;
}

function extractFromDom($: cheerio.CheerioAPI, limit: number): LeBonCoinSearchItem[] {
  const items: LeBonCoinSearchItem[] = [];
  const seen = new Set<string>();

  $('article, [data-test-id="ad"]').each((_i, el) => {
    if (items.length >= limit) return false;
    const $root = $(el);
    const title =
      $root.find('[data-test-id="adcard-title"]').first().text().trim() ||
      $root.find('h2, h3').first().text().trim();
    if (!title) return;

    const href =
      $root.find('a[href*="/ad/"]').first().attr('href')?.trim() ||
      $root.find('a[href]').first().attr('href')?.trim() ||
      '';
    if (!href) return;
    const listingUrl = toAbsoluteUrl(href);
    if (!listingUrl || seen.has(listingUrl)) return;
    seen.add(listingUrl);

    const priceRaw = $root.find('[data-test-id="price"]').first().text().trim();
    const { price, currency } = parsePrice(priceRaw);
    const image = pickImageFromCard($root);

    const location =
      $root.find('[data-test-id*="location"]').first().text().trim() ||
      $root.find('[data-qa-id*="location"]').first().text().trim() ||
      undefined;
    const category =
      $root.find('[data-test-id*="category"]').first().text().trim() ||
      $root.find('[data-qa-id*="category"]').first().text().trim() ||
      undefined;

    items.push({
      source: 'Le Bon Coin',
      sourceKey: 'leboncoin',
      title,
      ...(price !== undefined ? { price } : {}),
      ...(currency ? { currency } : {}),
      ...(image ? { imageUrl: image, thumbnailUrl: image } : {}),
      listingUrl,
      ...(location ? { location } : {}),
      ...(category ? { category } : {}),
    });
    return undefined;
  });
  return items;
}

function parseLeBonCoinHtml(html: string, limit: number): LeBonCoinSearchResult {
  const $ = cheerio.load(html);
  const totalCount = extractTotalCount($);
  const fromStructured = extractFromStructuredData($, limit);
  const items = fromStructured.length > 0 ? fromStructured : extractFromDom($, limit);
  return { items, totalCount };
}

export async function searchLeBonCoinByTextBrowser(
  query: string,
  options?: LeBonCoinSearchOptions
): Promise<LeBonCoinSearchResult> {
  const q = query.trim();
  if (!q) return { items: [] };

  const pageNumber = Math.max(1, Math.floor(options?.page ?? 1));
  const limit = Math.max(
    1,
    Math.min(LEBONCOIN_MAX_PER_PAGE, Math.floor(options?.limit ?? LEBONCOIN_MAX_PER_PAGE))
  );
  const url = buildLeBonCoinSearchUrl(q, pageNumber);
  console.log('[LEBONCOIN_BROWSER_URL]', url);

  let browser: Browser | undefined;
  let context: BrowserContext | undefined;
  let page: Page | undefined;
  try {
    browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-dev-shm-usage'],
    });
    context = await browser.newContext({
      userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      locale: 'fr-FR',
    });
    page = await context.newPage();

    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => undefined);
    await page
      .waitForSelector('article, [data-test-id="ad"], [data-test-id="adcard-title"]', {
        timeout: 12000,
      })
      .catch(() => undefined);

    const html = await page.content();
    const result = parseLeBonCoinHtml(html, limit);
    if (result.totalCount !== undefined) {
      console.log('[LEBONCOIN_TOTAL_COUNT]', result.totalCount);
    }
    if (pageNumber <= 1) {
      console.log('[LEBONCOIN_BROWSER_PAGE_1_COUNT]', result.items.length);
    } else {
      console.log('[LEBONCOIN_BROWSER_PAGE_N_COUNT]', { page: pageNumber, count: result.items.length });
    }
    console.log('[LEBONCOIN_BROWSER_OK]');
    return result;
  } catch (err) {
    console.error('[LEBONCOIN_BROWSER_ERROR]', err);
    return { items: [] };
  } finally {
    await page?.close().catch(() => undefined);
    await context?.close().catch(() => undefined);
    await browser?.close().catch(() => undefined);
  }
}

