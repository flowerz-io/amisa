import type { MarketplaceListingDTO } from '../../types.js';
import { ProviderScrapeError } from '../../lib/provider-scrape-error.js';
import {
  launchChromiumHeadless,
  PLAYWRIGHT_UA,
} from '../../lib/playwright-browser.js';

function rootKeysPreview(data: unknown, max = 24): string[] {
  if (!data || typeof data !== 'object') return [];
  return Object.keys(data as object).slice(0, max);
}

/** Extrait un tableau produit quel que soit le gabarit récent de l’API search. */
function depopProductsFromPayload(data: unknown): unknown[] {
  if (!data || typeof data !== 'object') return [];
  const root = data as Record<string, unknown>;
  const tryArrays: unknown[][] = [];
  if (Array.isArray(root.products)) tryArrays.push(root.products);
  if (Array.isArray(root.items)) tryArrays.push(root.items);
  if (root.data && typeof root.data === 'object') {
    const d = root.data as Record<string, unknown>;
    if (Array.isArray(d.products)) tryArrays.push(d.products);
    if (Array.isArray(d.items)) tryArrays.push(d.items);
    if (Array.isArray(d.results)) tryArrays.push(d.results);
    if (Array.isArray(d.hits)) tryArrays.push(d.hits);
  }
  for (const arr of tryArrays) {
    if (arr.length > 0) return arr;
  }
  return [];
}

function depopPriceAndCurrency(row: Record<string, unknown>): {
  price: number;
  currency: string;
} {
  let price = 0;
  let currency = 'EUR';
  const pricing = row.pricing;
  if (pricing && typeof pricing === 'object' && !Array.isArray(pricing)) {
    const pr = pricing as Record<string, unknown>;
    const national = pr.national_price;
    if (national && typeof national === 'object') {
      const np = national as Record<string, unknown>;
      const tp = np.total_price ?? np.price;
      if (typeof tp === 'string' || typeof tp === 'number') {
        price = Number(tp);
      }
      if (typeof np.currency_name === 'string') {
        currency = np.currency_name.toUpperCase();
      }
    }
    const priceObj = pr.price;
    if (priceObj && typeof priceObj === 'object') {
      const po = priceObj as Record<string, unknown>;
      const tp = po.total_price ?? po.price ?? po.discounted;
      if (
        (price === 0 || !Number.isFinite(price)) &&
        (typeof tp === 'string' || typeof tp === 'number')
      ) {
        price = Number(tp);
      }
      const cur = po.currency_name ?? pr.currency;
      if (typeof cur === 'string') currency = cur.toUpperCase();
    }
  }
  const ipa = row.item_product_price;
  if (ipa && typeof ipa === 'object') {
    const p = ipa as Record<string, unknown>;
    const amt = p.amount ?? p.price_amount ?? p.value;
    if (typeof amt === 'string' || typeof amt === 'number') {
      price = Number(amt);
    }
    if (typeof p.currency === 'string') currency = p.currency.toUpperCase();
  }
  if (typeof row.price === 'number') price = row.price;
  else if (typeof row.price === 'string') price = Number(row.price);
  return {
    price: Number.isFinite(price) ? price : 0,
    currency,
  };
}

function parseDepopProducts(data: unknown, parseContext: string): MarketplaceListingDTO[] {
  const rawList = depopProductsFromPayload(data);
  console.log('[DEPOP_PARSE]', parseContext, {
    rawCount: rawList.length,
    rootKeys: rootKeysPreview(data),
  });

  const out: MarketplaceListingDTO[] = [];
  for (const raw of rawList) {
    if (!raw || typeof raw !== 'object') continue;
    const row = raw as Record<string, unknown>;
    const id = row.id ?? row.selling_id ?? row.product_id;
    const idStr =
      typeof id === 'number'
        ? String(id)
        : typeof id === 'string'
          ? id
          : undefined;
    if (!idStr) continue;

    const slug =
      typeof row.slug === 'string' ? row.slug : idStr;
    const description =
      typeof row.description === 'string'
        ? row.description
        : typeof row.title === 'string'
          ? row.title
          : `Depop ${idStr}`;

    const { price, currency } = depopPriceAndCurrency(row);

    let imageUrl: string | undefined;
    const pics = row.pictures;
    if (Array.isArray(pics) && pics[0] && typeof pics[0] === 'object') {
      const p0 = pics[0] as Record<string, unknown>;
      imageUrl =
        (typeof p0.url === 'string' && p0.url) ||
        (typeof p0['1280'] === 'string' && (p0['1280'] as string)) ||
        (typeof p0['640'] === 'string' && (p0['640'] as string)) ||
        (typeof p0.formatted_thumbnail === 'string' &&
          (p0.formatted_thumbnail as string)) ||
        undefined;
    }
    if (!imageUrl && typeof row.preview_image === 'string') {
      imageUrl = row.preview_image;
    }

    const listingUrl = `https://www.depop.com/products/${slug}/`;
    out.push({
      id: idStr,
      source: 'depop',
      title: description.slice(0, 500),
      price,
      currency,
      imageUrl,
      thumbnailUrl: imageUrl,
      listingUrl,
    });
  }

  console.log('[DEPOP_PARSE]', parseContext, {
    validListings: out.length,
    sampleTitle: out[0]?.title?.slice(0, 80),
  });
  return out;
}

/**
 * Depop — Playwright + fetch JSON dans le navigateur (contourne 403 serveur).
 */
export async function fetchDepopScraperListings(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  const country = process.env.DEPOP_COUNTRY?.trim() || 'fr';
  const language = process.env.DEPOP_LANGUAGE?.trim() || 'fr';
  const count = process.env.DEPOP_SCRAPER_ITEMS?.trim() || '24';

  const browser = await launchChromiumHeadless();
  try {
    const ctx = await browser.newContext({
      userAgent: PLAYWRIGHT_UA,
      locale: 'fr-FR',
      viewport: { width: 1280, height: 900 },
    });
    const page = await ctx.newPage();

    console.log('[DEPOP_FETCH] start', {
      searchText: searchText.slice(0, 120),
      country,
      language,
      itemsCount: count,
    });

    await page.goto('https://www.depop.com/', {
      waitUntil: 'domcontentloaded',
      timeout: 45000,
    });

    const payload = await page.evaluate(
      async ({
        what,
        items_count,
        country: cty,
        language: lang,
      }: {
        what: string;
        items_count: string;
        country: string;
        language: string;
      }) => {
        const params = new URLSearchParams({
          what,
          items_count: items_count,
          country: cty,
          language: lang,
        });
        const url = `https://webapi.depop.com/api/v2/search/products/?${params.toString()}`;
        const r = await fetch(url, {
          headers: {
            Accept: 'application/json',
            Origin: 'https://www.depop.com',
            Referer: 'https://www.depop.com/',
          },
        });
        const text = await r.text();
        return { status: r.status, text, requestUrl: url };
      },
      {
        what: searchText,
        items_count: count,
        country,
        language,
      }
    );

    console.log('[DEPOP_FETCH] response', {
      status: payload.status,
      bodyChars: payload.text.length,
      head: payload.text.slice(0, 160).replace(/\s+/g, ' '),
    });

    if (payload.status === 403) {
      throw new ProviderScrapeError(
        'depop: accès API refusé HTTP 403 depuis le navigateur',
        403,
        true
      );
    }

    if (payload.status >= 400) {
      throw new Error(
        `depop: API HTTP ${payload.status} ${payload.text.slice(0, 280)}`
      );
    }

    let data: unknown;
    try {
      data = JSON.parse(payload.text);
    } catch {
      throw new Error(
        `depop: corps non-JSON HTTP ${payload.status} ${payload.text.slice(0, 220)}`
      );
    }

    const listings = parseDepopProducts(data, 'api_v2_search_products');
    if (listings.length === 0) {
      throw new Error(
        'depop: aucun produit extrait (clés API ou schéma modifié — voir [DEPOP_PARSE])'
      );
    }
    return listings;
  } finally {
    await browser.close();
  }
}
