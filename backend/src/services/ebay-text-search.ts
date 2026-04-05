import * as cheerio from 'cheerio';
import { chromium } from 'playwright';
import type { Browser, BrowserContext, Page } from 'playwright';
import { EBAY_MAX_PER_PAGE } from '../marketplace-limits.js';

const EBAY_ORIGIN = 'https://www.ebay.fr';

export type EbaySearchItem = {
  source: 'eBay';
  sourceKey: 'ebay';
  listingId?: string;
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
};

export type EbaySearchOptions = {
  page?: number;
  limit?: number;
};

export type EbaySearchResult = {
  items: EbaySearchItem[];
  totalCount?: number;
  stopReason?:
    | 'ok'
    | 'provider_blocked_by_challenge'
    | 'dom_not_ready'
    | 'page_closed'
    | 'page_crashed'
    | 'provider_unavailable';
};

const CARD_SELECTORS = [
  'ul.srp-results > li.s-item',
  'li.s-item',
  'div.s-card',
  'div.su-card-container',
  '[data-view*="mi:"]',
] as const;

const DOM_READY_SELECTORS = [
  'ul.srp-results',
  'li.s-item',
  'div.s-card',
  'div.s-card-container',
  '[data-view="mi:1"]',
  '[data-view^="mi:"]',
  'a[href*="/itm/"]',
] as const;

function encodeEbayKeywords(input: string): string {
  return encodeURIComponent(input.trim()).replace(/%20/g, '+');
}

export function buildEbaySearchUrl(query: string, page: number = 1): string {
  const q = encodeEbayKeywords(query);
  const base = `${EBAY_ORIGIN}/sch/i.html?_nkw=${q}`;
  if (page <= 1) return base;
  return `${base}&_pgn=${page}`;
}

function toAbsoluteUrl(href: string): string {
  const t = href.trim();
  if (!t) return '';
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  if (t.startsWith('//')) return `https:${t}`;
  return `${EBAY_ORIGIN}${t.startsWith('/') ? '' : '/'}${t}`;
}

function parsePrice(raw: string): { price?: number; currency?: string } {
  const text = (raw ?? '').replace(/\u00a0/g, ' ').trim();
  if (!text) return {};
  const upper = text.toUpperCase();
  const currency = upper.includes('EUR') || text.includes('€')
    ? 'EUR'
    : upper.includes('GBP') || text.includes('£')
      ? 'GBP'
      : upper.includes('USD') || text.includes('$')
        ? 'USD'
        : 'EUR';
  const m = text.match(/(\d[\d.,\s]*)/);
  if (!m) return { currency };
  const num = m[1].replace(/\s/g, '');
  const normalized = num.includes(',') && !num.includes('.') ? num.replace(/\./g, '').replace(',', '.') : num.replace(/,/g, '');
  const n = parseFloat(normalized);
  if (!Number.isFinite(n)) return { currency };
  return { price: n, currency };
}

function formatMarketplacePriceForLog(value: number | undefined, currency: string | undefined): string {
  if (value === undefined || !Number.isFinite(value)) return '—';
  const c = (currency ?? 'EUR').toUpperCase();
  if (c === 'EUR') {
    const fr = new Intl.NumberFormat('fr-FR', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(value);
    return `${fr} €`;
  }
  if (c === 'USD') {
    return `$${value.toFixed(2)}`;
  }
  if (c === 'GBP') {
    return `£${value.toFixed(2)}`;
  }
  return value.toFixed(2);
}

function inferBrandFromTitle(title: string): string | undefined {
  const t = title.trim();
  if (!t) return undefined;
  const first = t.split(/\s+/)[0]?.trim();
  if (!first) return undefined;
  if (first.length <= 1) return undefined;
  if (/^\d+$/.test(first)) return undefined;
  return first;
}

function inferSize(title: string): string | undefined {
  const t = title;
  const patterns = [
    /\b(?:taille|size)\s*[:\-]?\s*([a-z0-9+\-\/]+)/i,
    /\b(XXS|XS|S|M|L|XL|XXL|XXXL)\b/i,
    /\bW\d{2}\b/i,
  ];
  for (const p of patterns) {
    const m = t.match(p);
    if (m?.[1]) return m[1].toUpperCase();
    if (!m?.[1] && m?.[0]) return m[0].toUpperCase();
  }
  return undefined;
}

function inferCondition(subText: string): string | undefined {
  const t = subText.toLowerCase();
  if (!t) return undefined;
  if (t.includes('neuf')) return 'Neuf';
  if (t.includes('occasion')) return 'Occasion';
  if (t.includes('used')) return 'Used';
  if (t.includes('new')) return 'New';
  return undefined;
}

function isPlaceholderImage(url: string): boolean {
  const t = url.toLowerCase();
  return t.includes('ebaystatic.com/pictures/aw/pics/stockimage') || t.includes('thumbs.ebaystatic.com/pict/');
}

function extractTotalCount($: cheerio.CheerioAPI): number | undefined {
  const candidates = [
    $('.srp-controls__count-heading .BOLD').first().text().trim(),
    $('.srp-controls__count-heading').first().text().trim(),
    $('h1.srp-controls__count-heading').first().text().trim(),
  ];
  for (const c of candidates) {
    const m = c.replace(/\u00a0/g, ' ').match(/([\d\s.,]+)/);
    if (!m) continue;
    const n = parseInt(m[1].replace(/[^\d]/g, ''), 10);
    if (Number.isFinite(n)) return n;
  }
  return undefined;
}

function isInvalidCard(title: string, listingUrl: string): boolean {
  const t = title.toLowerCase();
  if (!listingUrl.includes('/itm/')) return true;
  if (t.includes('shop on ebay')) return true;
  if (t.includes('sponsored')) return true;
  if (t.includes('explore more options')) return true;
  if (t.includes('résultats correspondant à')) return true;
  return false;
}

function firstTextBySelectors($root: cheerio.Cheerio<any>, selectors: string[]): string {
  for (const sel of selectors) {
    const t = $root.find(sel).first().text().trim();
    if (t) return t;
  }
  return '';
}

function firstAttrBySelectors(
  $root: cheerio.Cheerio<any>,
  selectors: string[],
  attr: string
): string {
  for (const sel of selectors) {
    const v = $root.find(sel).first().attr(attr)?.trim();
    if (v) return v;
  }
  return '';
}

function logCardSelectorDiagnostics($: cheerio.CheerioAPI): { selected: cheerio.Cheerio<any>; selector: string; count: number } {
  let selected: cheerio.Cheerio<any> = $([]);
  let selectorUsed: string = CARD_SELECTORS[0];
  let selectedCount = 0;

  for (const selector of CARD_SELECTORS) {
    const nodes = $(selector);
    const count = nodes.length;
    console.log(`[EBAY_CARD_SELECTOR_MATCH] selector=${selector} count=${count}`);
    for (let i = 0; i < Math.min(3, count); i++) {
      const sample = $(nodes[i]).html()?.replace(/\s+/g, ' ').slice(0, 420) ?? '';
      console.log(`[EBAY_CARD_SAMPLE_HTML] selector=${selector} idx=${i} html=${sample}`);
    }
    if (count > selectedCount) {
      selected = nodes;
      selectorUsed = selector;
      selectedCount = count;
    }
  }

  return { selected, selector: selectorUsed, count: selectedCount };
}

async function firstMatchingReadySelector(page: Page): Promise<string | null> {
  const rounds = 6;
  for (let round = 1; round <= rounds; round++) {
    for (const selector of DOM_READY_SELECTORS) {
      console.log(`[EBAY_DOM_READY_SELECTOR_TRY] round=${round} selector=${selector}`);
      const count = await page
        .locator(selector)
        .count()
        .catch(() => 0);
      if (count > 0) {
        console.log(`[EBAY_DOM_READY_SELECTOR_OK] round=${round} selector=${selector} count=${count}`);
        return selector;
      }
      console.log(`[EBAY_DOM_READY_SELECTOR_FAIL] round=${round} selector=${selector} count=${count}`);
    }
    await page.waitForTimeout(800 * round);
  }
  return null;
}

async function logDomReadyFailureDiagnostics(page: Page): Promise<void> {
  const title = await page.title().catch(() => '(unavailable)');
  const finalUrl = page.url();
  const mainSnippet = await page
    .evaluate(() => {
      const el = document.querySelector('main, #mainContent, #srp-river-main, body');
      const html = (el?.innerHTML ?? document.body?.innerHTML ?? '').replace(/\s+/g, ' ').trim();
      return html.slice(0, 1600);
    })
    .catch(() => '(unavailable)');
  const foundCandidates = await page
    .evaluate(() => {
      const out: string[] = [];
      const push = (s: string) => {
        if (!s || out.includes(s)) return;
        out.push(s);
      };
      const nodes = Array.from(document.querySelectorAll('a[href*="/itm/"], [class*="s-item"], [class*="s-card"], li, ul, div')).slice(0, 200);
      for (const node of nodes) {
        if (out.length >= 10) break;
        const el = node as HTMLElement;
        const tag = el.tagName.toLowerCase();
        if (el.id) push(`${tag}#${el.id}`);
        const cls = (el.className || '').toString().trim().split(/\s+/).filter(Boolean);
        if (cls.length > 0) push(`${tag}.${cls.slice(0, 2).join('.')}`);
        const dv = el.getAttribute('data-view');
        if (dv) push(`${tag}[data-view="${dv}"]`);
      }
      return out.slice(0, 10);
    })
    .catch(() => [] as string[]);

  console.log('[EBAY_DOM_READY_FAILED_TITLE]', title);
  console.log('[EBAY_DOM_READY_FAILED_URL]', finalUrl);
  console.log('[EBAY_DOM_READY_FAILED_MAIN_SNIPPET]', mainSnippet);
  console.log('[EBAY_DOM_READY_FAILED_CANDIDATES]', JSON.stringify(foundCandidates));
}

function looksLikeChallengeUrl(url: string): boolean {
  const u = url.toLowerCase();
  return u.includes('/splashui/challenge') || u.includes('challenge') || u.includes('captcha');
}

async function detectChallenge(page: Page): Promise<{ blocked: boolean; url: string }> {
  const currentUrl = page.url();
  if (looksLikeChallengeUrl(currentUrl)) {
    return { blocked: true, url: currentUrl };
  }
  const marker = await page
    .evaluate(() => {
      const txt = (document.body?.innerText ?? '').toLowerCase();
      const title = (document.title ?? '').toLowerCase();
      const hit =
        txt.includes('captcha') ||
        txt.includes('attention required') ||
        txt.includes('verify you are a human') ||
        txt.includes('security measure') ||
        title.includes('captcha') ||
        title.includes('challenge');
      return hit;
    })
    .catch(() => false);
  return { blocked: marker, url: currentUrl };
}

export async function searchEbayByText(
  query: string,
  options?: EbaySearchOptions
): Promise<EbaySearchResult> {
  const q = query.trim();
  if (!q) return { items: [] };

  const page = Math.max(1, Math.floor(options?.page ?? 1));
  const limit = Math.max(1, Math.min(EBAY_MAX_PER_PAGE, Math.floor(options?.limit ?? EBAY_MAX_PER_PAGE)));
  const url = buildEbaySearchUrl(q, page);
  console.log('[EBAY_SEARCH_URL]', url);
  console.log('[EBAY_BROWSER_URL]', url);

  let browser: Browser | undefined;
  let context: BrowserContext | undefined;
  let pageHandle: Page | undefined;
  let pageCrashed = false;
  let html = '';
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
    pageHandle = await context.newPage();
    pageHandle.on('crash', () => {
      pageCrashed = true;
      console.log('[EBAY_STOP_REASON] page_crashed');
    });
    await pageHandle.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
    console.log('[EBAY_NAVIGATED_URL]', url);
    await pageHandle.waitForLoadState('domcontentloaded', { timeout: 10000 }).catch(() => undefined);
    await pageHandle.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => undefined);
    console.log('[EBAY_FINAL_URL]', pageHandle.url());

    const challenge = await detectChallenge(pageHandle);
    if (challenge.blocked) {
      console.log('[EBAY_CHALLENGE_DETECTED]', challenge.url);
      console.log('[EBAY_STOP_REASON] provider_blocked_by_challenge');
      return { items: [], stopReason: 'provider_blocked_by_challenge' };
    }

    if (pageHandle.isClosed()) {
      console.log('[EBAY_STOP_REASON] page_closed');
      return { items: [], stopReason: 'page_closed' };
    }
    if (pageCrashed) {
      console.log('[EBAY_STOP_REASON] page_crashed');
      return { items: [], stopReason: 'page_crashed' };
    }

    const domReadySelector = await firstMatchingReadySelector(pageHandle);
    if (!domReadySelector) {
      await logDomReadyFailureDiagnostics(pageHandle);
      console.log('[EBAY_FINAL_READY_SELECTOR] none');
      console.log('[EBAY_STOP_REASON] dom_not_ready');
      return { items: [], stopReason: 'dom_not_ready' };
    } else {
      console.log('[EBAY_DOM_READY_SELECTOR_OK]', domReadySelector);
      console.log('[EBAY_FINAL_READY_SELECTOR]', domReadySelector);
      console.log('[EBAY_BROWSER_DOM_READY]', domReadySelector);
    }

    if (pageHandle.isClosed()) {
      console.log('[EBAY_STOP_REASON] page_closed');
      return { items: [], stopReason: 'page_closed' };
    }
    if (pageCrashed) {
      console.log('[EBAY_STOP_REASON] page_crashed');
      return { items: [], stopReason: 'page_crashed' };
    }
    html = await pageHandle.content().catch((err) => {
      console.error('[EBAY_PROVIDER_ERROR]', err);
      return '';
    });
    if (!html) {
      const reason = pageCrashed ? 'page_crashed' : pageHandle.isClosed() ? 'page_closed' : 'provider_unavailable';
      console.log(`[EBAY_STOP_REASON] ${reason}`);
      return { items: [], stopReason: reason };
    }
    console.log('[EBAY_BROWSER_HTML_LENGTH]', html.length);
  } catch (err) {
    console.error('[EBAY_PROVIDER_ERROR]', err);
    if (pageCrashed) {
      console.log('[EBAY_STOP_REASON] page_crashed');
      return { items: [], stopReason: 'page_crashed' };
    }
    return { items: [], stopReason: 'provider_unavailable' };
  } finally {
    await pageHandle?.close().catch(() => undefined);
    await context?.close().catch(() => undefined);
    await browser?.close().catch(() => undefined);
  }

  const $ = cheerio.load(html);
  const totalCount = extractTotalCount($);
  if (totalCount !== undefined) {
    console.log('[EBAY_TOTAL_COUNT]', totalCount);
  }

  const items: EbaySearchItem[] = [];
  const seen = new Set<string>();
  const { selected: cards, selector: selectorUsed, count: selectedCount } = logCardSelectorDiagnostics($);
  console.log(`[EBAY_CARD_SELECTOR_USED] selector=${selectorUsed} count=${selectedCount}`);

  cards.each((index, el) => {
    if (items.length >= limit) return false;
    const $root = $(el);

    const link = firstAttrBySelectors(
      $root,
      [
        'a.s-item__link[href]',
        'a.s-card__link[href]',
        'a[href*="/itm/"]',
        'a[href*="itm"]',
      ],
      'href'
    );
    const listingUrl = toAbsoluteUrl(link);
    if (!listingUrl) {
      console.log('[EBAY_CARD_PARSE_SKIPPED] reason=missing_link');
      return;
    }
    if (seen.has(listingUrl)) {
      console.log('[EBAY_CARD_PARSE_SKIPPED] reason=duplicate_link');
      return;
    }

    const title = firstTextBySelectors($root, [
      '.s-item__title',
      '.su-card__title',
      '[data-testid="title"]',
      '[role="heading"]',
      'h3',
    ]);
    if (!title) {
      console.log('[EBAY_CARD_PARSE_SKIPPED] reason=missing_title');
      return;
    }
    if (isInvalidCard(title, listingUrl)) {
      console.log('[EBAY_CARD_PARSE_SKIPPED] reason=invalid_card_type');
      return;
    }

    const priceText = firstTextBySelectors($root, [
      'span.s-card__price',
      '.s-card__price',
      'span[class*="price"]',
      '[class*="s-card__price"]',
      '.s-item__price',
      '.su-card__price',
      '[data-testid*="price"]',
      '.POSITIVE',
    ]);
    console.log('[EBAY_PRICE_RAW]', priceText || '(empty)');
    const { price, currency } = parsePrice(priceText);
    console.log('[EBAY_PRICE_PARSED]', price ?? '(none)');
    console.log('[EBAY_CURRENCY_DETECTED]', currency ?? '(none)');
    console.log('[EBAY_PRICE_DISPLAY]', formatMarketplacePriceForLog(price, currency));

    const hasRawPrice = priceText.trim().length > 0;
    if (price === undefined && !hasRawPrice) {
      console.log('[EBAY_CARD_PARSE_SKIPPED] reason=missing_price_and_raw_absent');
      return;
    }

    const image =
      firstAttrBySelectors($root, ['img.s-item__image-img', 'img.su-card__image', 'img'], 'data-src') ||
      firstAttrBySelectors($root, ['img.s-item__image-img', 'img.su-card__image', 'img'], 'src');
    if (!image || isPlaceholderImage(image)) {
      console.log('[EBAY_CARD_PARSE_SKIPPED] reason=missing_or_placeholder_image');
      return;
    }

    const listingId =
      listingUrl.match(/\/itm\/(?:[^/]*\/)?(\d{8,15})/i)?.[1] ||
      $root.attr('data-view')?.match(/mi:(\d+)/)?.[1];

    const subtitle = $root.find('.s-item__subtitle').first().text().trim();
    const conditionText = $root.find('.SECONDARY_INFO').first().text().trim();
    const mergedSub = `${subtitle} ${conditionText}`.trim();

    const brand = inferBrandFromTitle(title);
    const size = inferSize(title);
    const condition = inferCondition(mergedSub);
    const published = $root.find('.s-item__ended-date, .s-item__time-left').first().text().trim() || undefined;

    const dedupeKey = listingId ? `ebay|${listingId}` : `ebay|${listingUrl}`;
    if (seen.has(dedupeKey)) {
      console.log('[EBAY_CARD_PARSE_SKIPPED] reason=duplicate_id');
      return;
    }
    seen.add(listingUrl);
    seen.add(dedupeKey);

    const parsed: EbaySearchItem = {
      source: 'eBay',
      sourceKey: 'ebay',
      ...(listingId ? { listingId } : {}),
      sourceRank: index + 1,
      title,
      price: price ?? 0,
      currency: currency ?? 'EUR',
      imageUrl: image,
      thumbnailUrl: image,
      listingUrl,
      ...(brand ? { brand } : {}),
      ...(size ? { size } : {}),
      ...(condition ? { condition } : {}),
      ...(published ? { publishedAtRelative: published } : {}),
    };
    items.push(parsed);
    console.log(
      `[EBAY_CARD_PARSE_OK] rank=${parsed.sourceRank ?? -1} listingId=${parsed.listingId ?? 'none'} title=${parsed.title.slice(0, 90)}`
    );
    return undefined;
  });

  if (page <= 1) {
    console.log('[EBAY_PAGE_1_COUNT]', items.length);
  } else {
    console.log('[EBAY_PAGE_N_COUNT]', { page, count: items.length });
  }

  return { items, totalCount, stopReason: 'ok' };
}

