import * as cheerio from 'cheerio';

const VINTED_ORIGIN = 'https://www.vinted.fr';
const MAX_RESULTS = 10;

const FETCH_HEADERS: Record<string, string> = {
  'User-Agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.5',
};

export type VintedSearchItem = {
  title: string;
  imageUrl: string;
  listingUrl: string;
  /** Marque (ligne au-dessus de l’état sur la carte catalogue) */
  brand?: string;
  size?: string;
  condition?: string;
  /** Prix principal : préférence prix acheteur (frais inclus) si présent sur la carte */
  price?: number;
  currency?: string;
  source: 'Vinted';
};

export function buildVintedSearchUrl(searchText: string, page: number = 1): string {
  const base = `https://www.vinted.fr/catalog?search_text=${encodeURIComponent(searchText.trim())}`;
  if (page <= 1) return base;
  return `${base}&page=${page}`;
}

function toAbsoluteUrl(href: string): string {
  const t = href.trim();
  if (!t) return '';
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  if (t.startsWith('//')) return `https:${t}`;
  return `${VINTED_ORIGIN}${t.startsWith('/') ? '' : '/'}${t}`;
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

/** Parse prix type "15,99 €" ou "120,00 €" */
function parseVintedPriceText(raw: string): { price?: number; currency?: string } {
  const s = raw.replace(/\u00a0/g, ' ').trim();
  if (!s) return {};
  const sym = s.includes('€') ? 'EUR' : s.includes('£') ? 'GBP' : s.includes('$') ? 'USD' : 'EUR';
  const numPart = s.replace(/[^\d,.-]/g, '').replace(/\s/g, '');
  if (!numPart) return { currency: sym };
  const normalized = numPart.includes(',') && !numPart.includes('.')
    ? numPart.replace(/\./g, '').replace(',', '.')
    : numPart.replace(',', '');
  const n = parseFloat(normalized);
  if (Number.isFinite(n)) return { price: n, currency: sym };
  return { currency: sym };
}

function extractTitleFromVintedText(text: string): string {
  const t = text.trim();
  if (!t) return '';
  const idxMarque = t.indexOf(', marque:');
  if (idxMarque > 0) return t.slice(0, idxMarque).trim();
  const idxEtat = t.indexOf(', état:');
  if (idxEtat > 0) return t.slice(0, idxEtat).trim();
  const idxEtatEn = t.indexOf(', condition:');
  if (idxEtatEn > 0) return t.slice(0, idxEtatEn).trim();
  return t;
}

function extractSizeFromTitle(title: string): string | undefined {
  const m = title.match(/\b(?:taille|size)\s*[:\s]?\s*([^\s,]+)/i);
  return m?.[1]?.trim();
}

export type VintedSearchOptions = {
  /** Page catalogue Vinted (1-based). */
  page?: number;
};

/**
 * Récupère jusqu'à 10 annonces par page depuis le catalogue Vinted (HTML serveur).
 */
export async function searchVintedByText(
  searchText: string,
  options?: VintedSearchOptions
): Promise<VintedSearchItem[]> {
  const q = searchText.trim();
  if (!q) {
    // eslint-disable-next-line no-console -- diagnostic recherche
    console.warn('[VINTED_SEARCH_SKIP_EMPTY_QUERY]');
    return [];
  }

  const page = Math.max(1, Math.floor(options?.page ?? 1));
  const url = buildVintedSearchUrl(q, page);
  // eslint-disable-next-line no-console -- diagnostic recherche
  console.log('[VINTED_FETCH]', url);

  const res = await fetch(url, { headers: FETCH_HEADERS, redirect: 'follow' });
  if (!res.ok) {
    // eslint-disable-next-line no-console -- diagnostic recherche
    console.error('[VINTED_FETCH_HTTP_ERROR]', res.status, res.statusText);
    throw new Error(`Vinted HTTP ${res.status}`);
  }

  const html = await res.text();
  const $ = cheerio.load(html);
  const items: VintedSearchItem[] = [];

  $('[data-testid="grid-item"]').each((_i, el) => {
    if (items.length >= MAX_RESULTS) return false;

    const $root = $(el);
    const $link = $root.find('a.new-item-box__overlay[href*="/items/"]').first();
    let href = $link.attr('href')?.trim() ?? '';
    if (!href) {
      const fallback = $root.find('a[href*="/items/"]').first().attr('href')?.trim() ?? '';
      href = fallback;
    }
    if (!href) return;

    const listingUrl = stripQuery(toAbsoluteUrl(href));

    const $img = $root.find('img[data-testid$="--image--img"]').first();
    const imgEl = $img.length ? $img : $root.find('.new-item-box__image img').first();
    const imageUrl = (imgEl.attr('src') ?? imgEl.attr('data-src') ?? '').trim();
    if (!imageUrl) return;

    const overlayTitle = $link.attr('title')?.trim() ?? '';
    const alt = imgEl.attr('alt')?.trim() ?? '';
    const titleBase = overlayTitle || alt;
    let title = extractTitleFromVintedText(titleBase);
    if (!title) title = 'Article Vinted';

    const condition = $root
      .find('[data-testid$="--description-subtitle"]')
      .first()
      .text()
      .trim();

    const brandRaw = $root.find('[data-testid$="--description-title"]').first().text().trim();
    let brandNorm: string | undefined =
      brandRaw.length > 0 ? brandRaw : undefined;
    if (brandNorm && title && brandNorm.toLowerCase() === title.toLowerCase()) {
      brandNorm = undefined;
    }

    // Prix vendeur (petit gris) — fallback
    const sellerPriceText = $root.find('[data-testid$="--price-text"]').first().text();
    // Prix total avec frais / protection acheteur (ligne mise en avant sur la carte)
    const buyerTotalText = $root.find('[data-testid="total-combined-price"]').first().text();

    let parsed = parseVintedPriceText(buyerTotalText);
    let priceSource: 'buyer_total' | 'seller' = 'buyer_total';
    if (parsed.price === undefined) {
      parsed = parseVintedPriceText(sellerPriceText);
      priceSource = 'seller';
    }

    const { price, currency } = parsed;

    if (priceSource === 'seller') {
      // eslint-disable-next-line no-console -- diagnostic parsing
      console.log('[VINTED_PRICE_USED_SELLER_NOT_BUYER_TOTAL]', listingUrl.slice(-48));
    }

    const size = extractSizeFromTitle(title);

    items.push({
      title,
      imageUrl,
      listingUrl,
      ...(brandNorm ? { brand: brandNorm } : {}),
      ...(size ? { size } : {}),
      ...(condition ? { condition } : {}),
      ...(price !== undefined ? { price } : {}),
      currency: currency ?? 'EUR',
      source: 'Vinted',
    });

    return undefined;
  });

  // eslint-disable-next-line no-console -- diagnostic recherche
  console.log('[VINTED_PARSED_COUNT]', items.length);

  return items;
}
