import type { MarketplaceListingDTO } from '../../types.js';
import { ProviderScrapeError } from '../../lib/provider-scrape-error.js';
import {
  detectVintedBlockFromApiPayload,
  isRetryableVintedBlock,
} from '../../lib/vinted-block-detect.js';
import {
  launchChromiumHeadless,
  PLAYWRIGHT_UA,
} from '../../lib/playwright-browser.js';
import { parseVintedCatalogResponse } from './vinted-catalog-parse.js';

const MAX_RETRIES = Number(process.env.VINTED_PLAYWRIGHT_RETRIES?.trim() || '3');
const RETRY_BASE_MS = Number(process.env.VINTED_PLAYWRIGHT_RETRY_MS?.trim() || '1200');
const CATALOG_SETTLE_MS = Number(
  process.env.VINTED_PLAYWRIGHT_SETTLE_MS?.trim() || '2500'
);

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

async function fetchCatalogJsonInPage(
  pwPage: import('playwright').Page,
  searchText: string,
  perPageStr: string,
  pageNum: number
): Promise<{ status: number; text: string }> {
  return pwPage.evaluate(
    async ({
      query,
      pp,
      page,
    }: {
      query: string;
      pp: string;
      page: number;
    }) => {
      const u = new URL('https://www.vinted.fr/api/v2/catalog/items');
      u.searchParams.set('search_text', query);
      u.searchParams.set('per_page', pp);
      u.searchParams.set('page', String(page));
      const r = await fetch(u.toString(), {
        credentials: 'include',
        headers: {
          Accept: 'application/json',
          'Accept-Language': 'fr-FR,fr;q=0.9',
        },
      });
      return { status: r.status, text: await r.text() };
    },
    { query: searchText, pp: perPageStr, page: pageNum }
  );
}

async function extractIdsFromCatalogHtml(
  pwPage: import('playwright').Page,
  catalogUrl: string
): Promise<string[]> {
  await pwPage.goto(catalogUrl, {
    waitUntil: 'domcontentloaded',
    timeout: 50000,
  });

  try {
    await pwPage.waitForFunction(
      () =>
        document.querySelectorAll('a[href*="/items/"]').length > 0 ||
        document.body.innerText.toLowerCase().includes('aucun résultat'),
      { timeout: 12000 }
    );
  } catch {
    console.log('[VINTED_PLAYWRIGHT] wait_for_items_timeout');
  }

  await sleep(CATALOG_SETTLE_MS);

  const html = await pwPage.content();
  const block = detectVintedBlockFromApiPayload(200, html);
  if (block) {
    throw new ProviderScrapeError(
      `vinted: page catalogue bloquée (${block})`,
      403,
      true
    );
  }

  return pwPage.evaluate(() => {
    const seen = new Set<string>();
    for (const a of Array.from(
      document.querySelectorAll('a[href*="/items/"]')
    )) {
      const m = (a as HTMLAnchorElement).href.match(/\/items\/(\d+)/);
      if (m?.[1]) seen.add(m[1]);
    }
    return Array.from(seen);
  });
}

async function fetchOnceViaPlaywright(
  searchText: string,
  page: number
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
      timeout: 50000,
    });
    await sleep(800);

    const payload = await fetchCatalogJsonInPage(
      pwPage,
      searchText,
      perPageStr,
      safePage
    );

    const block = detectVintedBlockFromApiPayload(payload.status, payload.text);
    if (block === 'http_403' || block === 'api_code_100') {
      throw new ProviderScrapeError(
        `vinted: accès refusé (${block})`,
        payload.status === 403 ? 403 : 200,
        true
      );
    }

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
      if (parsed.listings.length > 0) {
        console.log('[VINTED_PLAYWRIGHT] api_json_ok', {
          count: parsed.listings.length,
          query: searchText.slice(0, 60),
        });
        return parsed;
      }
      console.log('[VINTED_PLAYWRIGHT] api_json_empty', { query: searchText.slice(0, 60) });
    } catch (parseErr) {
      console.log('[VINTED_PLAYWRIGHT] catalogue_json_fallback_html', parseErr);
    }

    if (safePage !== 1) {
      throw new Error(
        'vinted: pas de fallback HTML pour page>1 — catalogue JSON vide ou invalide'
      );
    }

    const ids = await extractIdsFromCatalogHtml(pwPage, catalogUrl);

    if (ids.length === 0) {
      console.log('[VINTED_PLAYWRIGHT] html_fallback_empty', {
        query: searchText.slice(0, 60),
      });
      return { listings: [], hasMore: false };
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
    console.log('[VINTED_PLAYWRIGHT] html_fallback_ok', { count: listings.length });
    return {
      listings,
      hasMore: listings.length >= per,
    };
  } finally {
    await browser.close();
  }
}

/**
 * Vinted sans token : Playwright + fetch same-origin, retry automatique, détection blocage.
 */
export async function fetchVintedViaPlaywright(
  searchText: string,
  page: number = 1
): Promise<{ listings: MarketplaceListingDTO[]; hasMore: boolean }> {
  const attempts = Math.max(1, Math.min(5, Math.floor(MAX_RETRIES)));
  let lastError: unknown;

  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      const result = await fetchOnceViaPlaywright(searchText, page);
      if (result.listings.length > 0 || attempt === attempts) {
        return result;
      }
      console.log('[VINTED_PLAYWRIGHT] retry_empty', { attempt, query: searchText.slice(0, 60) });
      await sleep(RETRY_BASE_MS * attempt);
    } catch (e) {
      lastError = e;
      const reason =
        e instanceof ProviderScrapeError && e.blocked403
          ? 'blocked_403'
          : e instanceof Error
            ? e.message.slice(0, 80)
            : 'unknown';
      const retryable =
        e instanceof ProviderScrapeError
          ? e.blocked403 || isRetryableVintedBlock('http_403')
          : true;

      console.warn('[VINTED_PLAYWRIGHT] attempt_failed', {
        attempt,
        reason,
        retryable,
      });

      if (!retryable || attempt === attempts) break;
      await sleep(RETRY_BASE_MS * attempt);
    }
  }

  if (lastError instanceof ProviderScrapeError) throw lastError;
  if (lastError instanceof Error) throw lastError;
  throw new Error('vinted: échec Playwright après retries');
}
