import type { MarketplaceListingDTO } from '../../types.js';
import { ProviderScrapeError } from '../../lib/provider-scrape-error.js';
import {
  launchChromiumHeadless,
  PLAYWRIGHT_UA,
} from '../../lib/playwright-browser.js';

function parseDepopProducts(data: unknown): MarketplaceListingDTO[] {
  const root = data as Record<string, unknown>;
  const products = root.products ?? root.data;
  if (!Array.isArray(products)) {
    throw new Error('depop: no products[] in JSON');
  }

  const out: MarketplaceListingDTO[] = [];
  for (const raw of products) {
    if (!raw || typeof raw !== 'object') continue;
    const row = raw as Record<string, unknown>;
    const id = row.id ?? row.selling_id;
    const idStr =
      typeof id === 'number'
        ? String(id)
        : typeof id === 'string'
          ? id
          : undefined;
    if (!idStr) continue;

    const slug = typeof row.slug === 'string' ? row.slug : idStr;
    const description =
      typeof row.description === 'string'
        ? row.description
        : `Depop ${idStr}`;

    let price = 0;
    let currency = 'EUR';
    const pricing = row.pricing;
    if (pricing && typeof pricing === 'object' && !Array.isArray(pricing)) {
      const pr = pricing as Record<string, unknown>;
      const priceObj = pr.price;
      if (priceObj && typeof priceObj === 'object') {
        const po = priceObj as Record<string, unknown>;
        const tp = po.total_price ?? po.price;
        if (typeof tp === 'string' || typeof tp === 'number') {
          price = Number(tp);
        }
        const cur = po.currency_name ?? pr.currency;
        if (typeof cur === 'string') currency = cur.toUpperCase();
      }
    }

    let imageUrl: string | undefined;
    const pics = row.pictures;
    if (Array.isArray(pics) && pics[0] && typeof pics[0] === 'object') {
      const p0 = pics[0] as Record<string, unknown>;
      imageUrl =
        (typeof p0.url === 'string' && p0.url) ||
        (typeof p0['1280'] === 'string' && (p0['1280'] as string)) ||
        (typeof p0['640'] === 'string' && (p0['640'] as string)) ||
        undefined;
    }

    const listingUrl = `https://www.depop.com/products/${slug}/`;
    out.push({
      id: idStr,
      source: 'Depop',
      title: description.slice(0, 500),
      price: Number.isFinite(price) ? price : 0,
      currency,
      imageUrl,
      thumbnailUrl: imageUrl,
      listingUrl,
    });
  }
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
          items_count,
          country: cty,
          language: lang,
        });
        const url = `https://webapi.depop.com/api/v2/search/products/?${params.toString()}`;
        const r = await fetch(url, {
          headers: { Accept: 'application/json' },
        });
        const text = await r.text();
        return { status: r.status, text };
      },
      {
        what: searchText,
        items_count: count,
        country,
        language,
      }
    );

    if (payload.status === 403) {
      throw new ProviderScrapeError(
        'depop: accès API refusé HTTP 403 depuis le navigateur',
        403,
        true
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

    const listings = parseDepopProducts(data);
    if (listings.length === 0) {
      throw new Error('depop: aucun résultat (réponse vide ou format modifié)');
    }
    return listings;
  } finally {
    await browser.close();
  }
}
