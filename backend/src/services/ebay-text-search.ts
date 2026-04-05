import * as cheerio from 'cheerio';
import { EBAY_MAX_PER_PAGE } from '../marketplace-limits.js';

const EBAY_ORIGIN = 'https://www.ebay.fr';

const FETCH_HEADERS: Record<string, string> = {
  'User-Agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.6',
  Referer: 'https://www.ebay.fr/',
};

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
};

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
  const currency = text.includes('€') ? 'EUR' : text.includes('£') ? 'GBP' : text.includes('$') ? 'USD' : 'EUR';
  const m = text.match(/(\d[\d.,\s]*)/);
  if (!m) return { currency };
  const num = m[1].replace(/\s/g, '');
  const normalized = num.includes(',') && !num.includes('.') ? num.replace(/\./g, '').replace(',', '.') : num.replace(/,/g, '');
  const n = parseFloat(normalized);
  if (!Number.isFinite(n)) return { currency };
  return { price: n, currency };
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
  return false;
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
  console.log('[EBAY_FETCH]', { page, limit });

  const res = await fetch(url, { headers: FETCH_HEADERS, redirect: 'follow' });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    console.error('[EBAY_PROVIDER_ERROR]', `HTTP ${res.status} ${res.statusText}`);
    if (body) console.error('[EBAY_ERROR_BODY]', body.slice(0, 800));
    throw new Error(`eBay HTTP ${res.status}`);
  }

  const html = await res.text();
  const $ = cheerio.load(html);
  const totalCount = extractTotalCount($);
  if (totalCount !== undefined) {
    console.log('[EBAY_TOTAL_COUNT]', totalCount);
  }

  const items: EbaySearchItem[] = [];
  const seen = new Set<string>();
  $('li.s-item, div.s-card, div.su-card-container').each((index, el) => {
    if (items.length >= limit) return false;
    const $root = $(el);

    const link =
      $root.find('a.s-item__link[href]').first().attr('href')?.trim() ||
      $root.find('a[href*="/itm/"]').first().attr('href')?.trim() ||
      '';
    const listingUrl = toAbsoluteUrl(link);
    if (!listingUrl || seen.has(listingUrl)) return;

    const title =
      $root.find('.s-item__title').first().text().trim() ||
      $root.find('[role="heading"]').first().text().trim() ||
      '';
    if (!title) return;
    if (isInvalidCard(title, listingUrl)) return;

    const priceText =
      $root.find('.s-item__price').first().text().trim() ||
      $root.find('[data-testid*="price"]').first().text().trim() ||
      '';
    const { price, currency } = parsePrice(priceText);
    if (price === undefined) return;

    const image =
      $root.find('img.s-item__image-img').first().attr('src')?.trim() ||
      $root.find('img.s-item__image-img').first().attr('data-src')?.trim() ||
      $root.find('img').first().attr('src')?.trim() ||
      '';
    if (!image || isPlaceholderImage(image)) return;

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
    if (seen.has(dedupeKey)) return;
    seen.add(listingUrl);
    seen.add(dedupeKey);

    items.push({
      source: 'eBay',
      sourceKey: 'ebay',
      ...(listingId ? { listingId } : {}),
      sourceRank: index + 1,
      title,
      price,
      currency: currency ?? 'EUR',
      imageUrl: image,
      thumbnailUrl: image,
      listingUrl,
      ...(brand ? { brand } : {}),
      ...(size ? { size } : {}),
      ...(condition ? { condition } : {}),
      ...(published ? { publishedAtRelative: published } : {}),
    });
    return undefined;
  });

  if (page <= 1) {
    console.log('[EBAY_PAGE_1_COUNT]', items.length);
  } else {
    console.log('[EBAY_PAGE_N_COUNT]', { page, count: items.length });
  }

  return { items, totalCount };
}

