import * as cheerio from 'cheerio';
import { chromium } from 'playwright';
import type { Browser, BrowserContext, Page } from 'playwright';
import { DEPOP_MAX_PER_PAGE } from '../marketplace-limits.js';

const DEPOP_ORIGIN = 'https://www.depop.com';

export type DepopSearchItem = {
  source: 'Depop';
  sourceKey: 'depop';
  providerItemId?: string;
  sourceRank?: number;
  title: string;
  price?: number;
  currency?: string;
  imageUrl?: string;
  thumbnailUrl?: string;
  listingUrl: string;
  brand?: string;
  size?: string;
  condition?: string;
  publishedAtRelative?: string;
  searchQuery: string;
};

export type DepopSearchOptions = {
  page?: number;
  limit?: number;
};

export type DepopSearchResult = {
  items: DepopSearchItem[];
  detectedCards: number;
};

function encodeDepopKeywords(input: string): string {
  return encodeURIComponent(input.trim()).replace(/%20/g, '+');
}

export function buildDepopSearchUrl(query: string): string {
  const q = encodeDepopKeywords(query);
  return `${DEPOP_ORIGIN}/search/?q=${q}`;
}

function toAbsoluteUrl(href: string): string {
  const t = href.trim();
  if (!t) return '';
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  if (t.startsWith('//')) return `https:${t}`;
  return `${DEPOP_ORIGIN}${t.startsWith('/') ? '' : '/'}${t}`;
}

function bestFromSrcset(srcset: string): string | undefined {
  const t = srcset.trim();
  if (!t) return undefined;
  const candidates = t
    .split(',')
    .map((part) => part.trim().split(/\s+/)[0]?.trim())
    .filter((x): x is string => !!x);
  return candidates[candidates.length - 1];
}

function parsePrice(raw: string): { price?: number; currency?: string } {
  const text = (raw ?? '').replace(/\u00a0/g, ' ').trim();
  if (!text) return {};
  const currency = text.includes('€')
    ? 'EUR'
    : text.includes('$')
      ? 'USD'
      : text.includes('£')
        ? 'GBP'
        : undefined;

  const m = text.match(/(\d[\d.,]*)/);
  if (!m) return { currency };
  const token = m[1].trim();
  let normalized = token;
  if (token.includes(',') && token.includes('.')) {
    normalized = token.replace(/,/g, '');
  } else if (token.includes(',')) {
    normalized = token.replace(',', '.');
  }
  const n = parseFloat(normalized);
  if (!Number.isFinite(n)) return { currency };
  return { price: n, currency };
}

function normalizeSize(raw: string): string {
  const t = raw.trim();
  if (!t) return '';
  return /[a-z]/i.test(t) ? t.toUpperCase() : t;
}

function inferProviderItemId(listingUrl: string): string | undefined {
  const m = listingUrl.match(/\/products\/([^/?#]+)/i);
  return m?.[1]?.trim() || undefined;
}

function parseDepopCardsFromHtml(
  html: string,
  query: string,
  page: number,
  limit: number
): DepopSearchResult {
  const $ = cheerio.load(html);
  const cards = $('ol[class*="styles_productGrid"] li[class*="styles_listItem"], li[class*="styles_listItem"]');
  const detectedCards = cards.length;
  console.log(`[DEPOP_CARD_COUNT] detected=${detectedCards} requestedPage=${page} limit=${limit}`);

  const all: DepopSearchItem[] = [];
  const seen = new Set<string>();

  cards.each((index, el) => {
    const $root = $(el);
    const href =
      $root.find('a.styles_unstyledLink__DsttP[href*="/products/"]').first().attr('href')?.trim() ||
      $root.find('a[href*="/products/"]').first().attr('href')?.trim() ||
      '';
    const listingUrl = toAbsoluteUrl(href);
    if (!listingUrl) {
      console.log('[DEPOP_PARSE_SKIPPED] reason=missing_link');
      return;
    }
    if (seen.has(listingUrl)) {
      console.log('[DEPOP_PARSE_SKIPPED] reason=duplicate_link');
      return;
    }

    const brandRaw = $root.find('p.styles_brandName__PHsIX, p[class*="styles_brandName"]').first().text().trim();
    const brand = brandRaw || 'No brand';

    const linkAria =
      $root.find('a.styles_unstyledLink__DsttP[href*="/products/"]').first().attr('aria-label')?.trim() ||
      $root.find('a[href*="/products/"]').first().attr('aria-label')?.trim() ||
      '';
    const imageAlt =
      $root.find('img._mainImage_e5j9l_11, img[class*="_mainImage"]').first().attr('alt')?.trim() || '';
    let title =
      linkAria ||
      imageAlt ||
      $root.find('h2, h3, p[class*="title"], p[data-testid*="title"]').first().text().trim() ||
      '';
    if (!title) {
      title = brandRaw ? `${brandRaw} ${query}` : query;
      console.log(`[DEPOP_TITLE_FALLBACK] listing=${listingUrl} title="${title}"`);
    }

    const sizeRaw =
      $root.find('p.styles_sizeAttributeText__r9QJj, p[class*="styles_sizeAttributeText"]').first().text().trim() ||
      '';
    const size = normalizeSize(sizeRaw);

    const discountedPriceRaw =
      $root
        .find(
          'p.styles_price__H8qdh[aria-label="Discounted price"], p[class*="styles_price"][aria-label*="Discounted"]'
        )
        .first()
        .text()
        .trim() || '';
    const normalPriceRaw =
      $root
        .find('p.styles_price__H8qdh[aria-label="Price"], p[class*="styles_price"][aria-label="Price"]')
        .first()
        .text()
        .trim() || '';
    const fallbackPriceRaw =
      $root.find('p.styles_price__H8qdh, p[class*="styles_price"]').first().text().trim() || '';
    const priceRaw = discountedPriceRaw || normalPriceRaw || fallbackPriceRaw;
    if (!priceRaw) {
      console.log('[DEPOP_PARSE_SKIPPED] reason=missing_price');
      return;
    }
    const { price, currency } = parsePrice(priceRaw);
    if (price === undefined) {
      console.log(`[DEPOP_PARSE_SKIPPED] reason=invalid_price raw="${priceRaw}"`);
      return;
    }

    const imageNode = $root.find('img._mainImage_e5j9l_11, img[class*="_mainImage"]').first();
    const src = imageNode.attr('src')?.trim() || imageNode.attr('data-src')?.trim() || '';
    const srcset = imageNode.attr('srcset')?.trim() || '';
    const imageUrl = src || bestFromSrcset(srcset) || undefined;
    if (!imageUrl) {
      console.log('[DEPOP_PARSE_SKIPPED] reason=missing_image');
      return;
    }

    const providerItemId = inferProviderItemId(listingUrl);
    const dedupeKey = providerItemId ? `depop|${providerItemId}` : `depop|${listingUrl}`;
    if (seen.has(dedupeKey)) {
      console.log('[DEPOP_PARSE_SKIPPED] reason=duplicate_provider_item_id');
      return;
    }
    seen.add(listingUrl);
    seen.add(dedupeKey);

    all.push({
      source: 'Depop',
      sourceKey: 'depop',
      ...(providerItemId ? { providerItemId } : {}),
      sourceRank: index + 1,
      title,
      price,
      currency: currency ?? 'EUR',
      imageUrl,
      thumbnailUrl: imageUrl,
      listingUrl,
      brand,
      ...(size ? { size } : {}),
      searchQuery: query,
    });
    return undefined;
  });

  const start = Math.max(0, (page - 1) * limit);
  const sliced = all.slice(start, start + limit);
  if (page <= 1) {
    console.log(`[DEPOP_INITIAL_COUNT] ${sliced.length}`);
  } else {
    console.log(`[DEPOP_PAGE_N_COUNT] page=${page} count=${sliced.length}`);
  }
  return {
    items: sliced,
    detectedCards: all.length,
  };
}

async function waitForGrid(page: Page): Promise<boolean> {
  const selectors = [
    'ol.styles_productGrid__Cpzyf',
    'ol[class*="styles_productGrid"]',
    'li.styles_listItem__Uv9lb',
    'li[class*="styles_listItem"]',
    'a[href*="/products/"]',
  ];
  for (const sel of selectors) {
    const found = await page
      .waitForSelector(sel, { timeout: 7000 })
      .then(() => true)
      .catch(() => false);
    if (found) {
      console.log(`[DEPOP_GRID_FOUND] selector=${sel}`);
      return true;
    }
  }
  return false;
}

async function scrollToPageTarget(
  page: Page,
  pageNumber: number,
  limit: number
): Promise<{ stopReason: string; cardsCount: number }> {
  const targetCards = pageNumber * limit;
  const countSelector = 'li[class*="styles_listItem"], a[href*="/products/"]';
  let previousCount = 0;
  let stableRounds = 0;
  const maxScrollAttempts = 12;

  for (let attempt = 1; attempt <= maxScrollAttempts; attempt++) {
    const cardsCount = await page.locator(countSelector).count();
    if (cardsCount >= targetCards) {
      return { stopReason: 'target_cards_reached', cardsCount };
    }
    await page.evaluate(() => {
      window.scrollBy(0, Math.round(window.innerHeight * 1.6));
    });
    await page.waitForTimeout(900);
    const nextCount = await page.locator(countSelector).count();
    if (nextCount <= previousCount) {
      stableRounds += 1;
    } else {
      stableRounds = 0;
    }
    previousCount = nextCount;
    if (stableRounds >= 3) {
      return { stopReason: 'no_new_cards_after_scroll', cardsCount: nextCount };
    }
  }

  const finalCount = await page.locator(countSelector).count();
  return { stopReason: 'max_scroll_attempts_reached', cardsCount: finalCount };
}

export async function searchDepopByTextBrowser(
  query: string,
  options?: DepopSearchOptions
): Promise<DepopSearchResult> {
  const q = query.trim();
  if (!q) return { items: [], detectedCards: 0 };

  const pageNumber = Math.max(1, Math.floor(options?.page ?? 1));
  const limit = Math.max(1, Math.min(DEPOP_MAX_PER_PAGE, Math.floor(options?.limit ?? DEPOP_MAX_PER_PAGE)));
  const url = buildDepopSearchUrl(q);
  console.log('[DEPOP_SEARCH_URL]', url);
  console.log('[DEPOP_BROWSER_URL]', url);

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
      locale: 'en-GB',
    });
    page = await context.newPage();
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.waitForLoadState('networkidle', { timeout: 12000 }).catch(() => undefined);

    const hasGrid = await waitForGrid(page);
    if (!hasGrid) {
      console.log('[DEPOP_STOP_REASON] grid_not_found');
      return { items: [], detectedCards: 0 };
    }

    const { stopReason, cardsCount } = await scrollToPageTarget(page, pageNumber, limit);
    console.log(`[DEPOP_STOP_REASON] ${stopReason}`);
    console.log(`[DEPOP_CARD_COUNT] after_scroll=${cardsCount}`);

    const html = await page.content();
    const parsed = parseDepopCardsFromHtml(html, q, pageNumber, limit);
    if (pageNumber <= 1) {
      console.log('[DEPOP_INITIAL_COUNT]', parsed.items.length);
    } else {
      console.log(`[DEPOP_NEXT_BATCH_COUNT] page=${pageNumber} count=${parsed.items.length}`);
    }
    return parsed;
  } catch (err) {
    console.error('[DEPOP_PROVIDER_ERROR]', err);
    return { items: [], detectedCards: 0 };
  } finally {
    await page?.close().catch(() => undefined);
    await context?.close().catch(() => undefined);
    await browser?.close().catch(() => undefined);
  }
}

