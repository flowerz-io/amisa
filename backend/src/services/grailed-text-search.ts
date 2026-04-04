import * as cheerio from 'cheerio';

const GRAILED_ORIGIN = 'https://www.grailed.com';
const MAX_RESULTS = 10;

const FETCH_HEADERS: Record<string, string> = {
  'User-Agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.9',
};

export type GrailedSearchItem = {
  title: string;
  imageUrl: string;
  listingUrl: string;
  brand?: string;
  size?: string;
  /** Prix affiché (Current) */
  price?: number;
  currency: string;
  source: 'Grailed';
};

export function buildGrailedSearchUrl(searchText: string, page: number = 1): string {
  const q = encodeURIComponent(searchText.trim());
  const base = `${GRAILED_ORIGIN}/shop?query=${q}`;
  if (page <= 1) return base;
  return `${base}&page=${page}`;
}

function toAbsoluteUrl(href: string): string {
  const t = href.trim();
  if (!t) return '';
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  if (t.startsWith('//')) return `https:${t}`;
  return `${GRAILED_ORIGIN}${t.startsWith('/') ? '' : '/'}${t}`;
}

function stripQuery(url: string): string {
  try {
    const u = new URL(url);
    u.search = '';
    return u.toString();
  } catch {
    return url;
  }
}

/** Prix type "$120" ou "$1,234.56" — devise USD par défaut (Grailed). */
function parseGrailedPriceText(raw: string): { price?: number; currency: string } {
  const s = raw.replace(/\u00a0/g, ' ').trim();
  if (!s) return { currency: 'USD' };
  const m = s.match(/\$?\s*([\d,]+(?:\.\d{1,2})?)/);
  if (!m) return { currency: 'USD' };
  const normalized = m[1].replace(/,/g, '');
  const n = parseFloat(normalized);
  if (!Number.isFinite(n)) return { currency: 'USD' };
  return { price: n, currency: 'USD' };
}

export type GrailedSearchOptions = {
  page?: number;
};

/**
 * Récupère jusqu'à 10 annonces depuis la page shop Grailed (HTML).
 * Sélecteurs basés sur des fragments de classe stables (contains), pas des hash CSS.
 */
export async function searchGrailedByText(
  searchText: string,
  options?: GrailedSearchOptions
): Promise<GrailedSearchItem[]> {
  const q = searchText.trim();
  if (!q) {
    // eslint-disable-next-line no-console -- diagnostic recherche
    console.warn('[GRAILED_SEARCH_SKIP_EMPTY_QUERY]');
    return [];
  }

  const page = Math.max(1, Math.floor(options?.page ?? 1));
  const url = buildGrailedSearchUrl(q, page);
  // eslint-disable-next-line no-console -- diagnostic recherche
  console.log('[GRAILED_FETCH]', url);

  const res = await fetch(url, { headers: FETCH_HEADERS, redirect: 'follow' });
  if (!res.ok) {
    // eslint-disable-next-line no-console -- diagnostic recherche
    console.error('[GRAILED_FETCH_HTTP_ERROR]', res.status, res.statusText);
    throw new Error(`Grailed HTTP ${res.status}`);
  }

  const html = await res.text();
  const $ = cheerio.load(html);
  const items: GrailedSearchItem[] = [];

  $('div[class*="UserItem_root"]').each((_i, el) => {
    if (items.length >= MAX_RESULTS) return false;

    const $card = $(el);

    const $link = $card.find('a[class*="UserItem_link"]').first();
    const href = $link.attr('href')?.trim() ?? '';
    if (!href) return;

    const title = $card.find('div[class*="UserItem_title"]').first().text().trim();
    if (!title) return;

    const listingUrl = stripQuery(toAbsoluteUrl(href));

    const $imgWrap = $card.find('div[class*="UserItem_listingCoverPhoto"]').first();
    const $img = $imgWrap.length ? $imgWrap.find('img').first() : $card.find('img').first();
    const imageUrl = ($img.attr('src') ?? $img.attr('data-src') ?? '').trim();
    if (!imageUrl) return;

    const brand = $card.find('div[class*="UserItem_designer"]').first().text().trim();
    const size = $card.find('div[class*="UserItem_size"]').first().text().trim();

    const currentText = $card.find('span[data-testid="Current"]').first().text();
    const { price, currency } = parseGrailedPriceText(currentText);

    items.push({
      title,
      imageUrl,
      listingUrl,
      ...(brand ? { brand } : {}),
      ...(size ? { size } : {}),
      ...(price !== undefined ? { price } : {}),
      currency: currency ?? 'USD',
      source: 'Grailed',
    });

    return undefined;
  });

  // eslint-disable-next-line no-console -- diagnostic recherche
  console.log('[GRAILED_PARSED_COUNT]', items.length);

  return items;
}
