import type { MarketplaceListingDTO } from '../../types.js';
import { ProviderScrapeError } from '../../lib/provider-scrape-error.js';
import {
  launchChromiumHeadless,
  PLAYWRIGHT_UA,
} from '../../lib/playwright-browser.js';
import { parseVintedCatalogPayload } from './vinted-catalog-parse.js';

/**
 * Vinted sans token : Playwright + fetch same-origin, puis fallback page catalogue (liens /items/).
 */
export async function fetchVintedViaPlaywright(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  const browser = await launchChromiumHeadless();
  const perPage = process.env.VINTED_SCRAPER_PER_PAGE?.trim() || '24';
  const catalogUrl = `https://www.vinted.fr/catalog?search_text=${encodeURIComponent(searchText)}`;

  try {
    const ctx = await browser.newContext({
      userAgent: PLAYWRIGHT_UA,
      locale: 'fr-FR',
      timezoneId: 'Europe/Paris',
      viewport: { width: 1280, height: 900 },
    });
    const page = await ctx.newPage();
    await page.goto('https://www.vinted.fr/', {
      waitUntil: 'domcontentloaded',
      timeout: 45000,
    });

    const payload = await page.evaluate(
      async ({
        query,
        pp,
      }: {
        query: string;
        pp: string;
      }) => {
        const u = new URL('https://www.vinted.fr/api/v2/catalog/items');
        u.searchParams.set('search_text', query);
        u.searchParams.set('per_page', pp);
        u.searchParams.set('page', '1');
        const r = await fetch(u.toString(), {
          credentials: 'include',
          headers: {
            Accept: 'application/json',
            'Accept-Language': 'fr-FR,fr;q=0.9',
          },
        });
        const text = await r.text();
        return { status: r.status, text };
      },
      { query: searchText, pp: perPage }
    );

    if (payload.status === 403) {
      throw new ProviderScrapeError(
        'vinted: accès refusé HTTP 403 (anti-bot)',
        403,
        true
      );
    }

    try {
      const data = JSON.parse(payload.text);
      const listings = parseVintedCatalogPayload(data, payload.status);
      if (listings.length > 0) return listings;
    } catch {
      console.log('[VINTED_PLAYWRIGHT] catalogue_json_fallback_html');
    }

    await page.goto(catalogUrl, {
      waitUntil: 'domcontentloaded',
      timeout: 45000,
    });
    await new Promise((r) => setTimeout(r, 1200));

    const ids = await page.evaluate(() => {
      const seen = new Set<string>();
      for (const a of Array.from(document.querySelectorAll('a[href*="/items/"]'))) {
        const m = (a as HTMLAnchorElement).href.match(/\/items\/(\d+)/);
        if (m?.[1]) seen.add(m[1]);
      }
      return Array.from(seen);
    });

    if (ids.length === 0) {
      throw new Error(
        'vinted: aucune annonce extraite — site injoignable ou structure HTML modifiée'
      );
    }

    return ids.slice(0, 24).map((id) => ({
      id,
      source: 'Vinted',
      title: `Vinted ${id}`,
      price: 0,
      currency: 'EUR',
      listingUrl: `https://www.vinted.fr/items/${id}`,
    }));
  } finally {
    await browser.close();
  }
}
