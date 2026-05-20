import type { MarketplaceListingDTO } from '../../types.js';
import { ProviderScrapeError } from '../../lib/provider-scrape-error.js';
import {
  launchChromiumHeadless,
  PLAYWRIGHT_UA,
} from '../../lib/playwright-browser.js';
import { parseVintedCatalogResponse } from './vinted-catalog-parse.js';

/**
 * Vinted sans token : Playwright + fetch same-origin, puis fallback page catalogue (liens /items/) pour page 1 seulement.
 */
export async function fetchVintedViaPlaywright(
  searchText: string,
  page: number = 1
): Promise<{ listings: MarketplaceListingDTO[]; hasMore: boolean }> {
  const browser = await launchChromiumHeadless();
  const perPageStr = process.env.VINTED_SCRAPER_PER_PAGE?.trim() || '24';
  const catalogUrl = `https://www.vinted.fr/catalog?search_text=${encodeURIComponent(searchText)}`;
  const safePage = Math.max(1, Math.floor(page));

  try {
    const ctx = await browser.newContext({
      userAgent: PLAYWRIGHT_UA,
      locale: 'fr-FR',
      timezoneId: 'Europe/Paris',
      viewport: { width: 1280, height: 900 },
    });
    const pwPage = await ctx.newPage();
    await pwPage.goto('https://www.vinted.fr/', {
      waitUntil: 'domcontentloaded',
      timeout: 45000,
    });

    const payload = await pwPage.evaluate(
      async ({
        query,
        pp,
        pageNum,
      }: {
        query: string;
        pp: string;
        pageNum: number;
      }) => {
        const u = new URL('https://www.vinted.fr/api/v2/catalog/items');
        u.searchParams.set('search_text', query);
        u.searchParams.set('per_page', pp);
        u.searchParams.set('page', String(pageNum));
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
      { query: searchText, pp: perPageStr, pageNum: safePage }
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
      const parsed = parseVintedCatalogResponse(data, payload.status);
      if (parsed.listings.length > 0) return parsed;
    } catch {
      console.log('[VINTED_PLAYWRIGHT] catalogue_json_fallback_html');
    }

    if (safePage !== 1) {
      throw new Error(
        'vinted: pas de fallback HTML pour page>1 — catalogue JSON vide ou invalide'
      );
    }

    await pwPage.goto(catalogUrl, {
      waitUntil: 'domcontentloaded',
      timeout: 45000,
    });
    await new Promise((r) => setTimeout(r, 1200));

    const ids = await pwPage.evaluate(() => {
      const seen = new Set<string>();
      for (const a of Array.from(
        document.querySelectorAll('a[href*="/items/"]')
      )) {
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

    const listings: MarketplaceListingDTO[] = ids.slice(0, 24).map((id) => ({
      id,
      source: 'vinted',
      title: `Vinted ${id}`,
      price: 0,
      currency: 'EUR',
      listingUrl: `https://www.vinted.fr/items/${id}`,
    }));
    const ppNum = Number(perPageStr);
    const per = Number.isFinite(ppNum) && ppNum > 0 ? ppNum : 24;
    return {
      listings,
      hasMore: listings.length >= per,
    };
  } finally {
    await browser.close();
  }
}
