import type { MarketplaceListingDTO } from '../../types.js';
import {
  launchChromiumHeadless,
  PLAYWRIGHT_UA,
} from '../../lib/playwright-browser.js';

function parseDepopPriceText(raw: string): { price: number; currency: string } {
  const t = raw.replace(/\s+/g, ' ').trim();
  if (!t) return { price: 0, currency: 'EUR' };
  let currency = 'EUR';
  if (t.includes('£') || /\bGBP\b/i.test(t)) currency = 'GBP';
  else if (t.includes('$') || /\bUSD\b/i.test(t)) currency = 'USD';
  const normalized = t.replace(/,/g, '.').replace(/[^\d.]/g, ' ');
  const parts = normalized.trim().split(/\s+/).filter(Boolean);
  const lastNum = [...parts].reverse().find((p) => /^\d+(\.\d+)?$/.test(p));
  const price = lastNum ? Number.parseFloat(lastNum) : Number.parseFloat(normalized.replace(/\s/g, ''));
  return { price: Number.isFinite(price) ? price : 0, currency };
}

type DepopDomRow = {
  slug: string;
  listingUrl: string;
  title: string;
  priceText: string;
  imageUrl: string;
};

/**
 * Extraction DOM uniquement (pas de `fetch()` dans le navigateur).
 */
async function extractDepopRowsFromDom(page: {
  evaluate: <T>(fn: () => T) => Promise<T>;
}): Promise<DepopDomRow[]> {
  return page.evaluate(() => {
    const out: DepopDomRow[] = [];
    const seen = new Set<string>();
    const anchors = Array.from(
      document.querySelectorAll('a[href*="/products/"]')
    ) as HTMLAnchorElement[];

    const absUrl = (href: string) =>
      href.startsWith('http') ? href : `https://www.depop.com${href}`;

    for (const a of anchors) {
      const href = a.getAttribute('href') || '';
      const m = href.match(/\/products\/([^/?#]+)/);
      if (!m) continue;
      const slug = m[1];
      if (seen.has(slug)) continue;

      let card: Element | null = a;
      let chosen: Element | null = null;
      for (let depth = 0; depth < 12 && card; depth++) {
        card = card.parentElement;
        if (!card) break;
        const imgs = card.querySelectorAll('img');
        const links = card.querySelectorAll('a[href*="/products/"]');
        if (imgs.length > 0 && links.length > 0) {
          chosen = card;
          break;
        }
      }
      if (!chosen) continue;

      let title = '';
      const pEls = chosen.querySelectorAll('p');
      for (const p of pEls) {
        const tx = p.textContent?.trim() || '';
        if (tx.length > 4 && tx.length < 240 && !/^[\d£€$.,\s]+$/.test(tx)) {
          title = tx;
          break;
        }
      }
      if (!title) {
        const h = chosen.querySelector('h1,h2,h3,h4');
        title = h?.textContent?.trim() || slug;
      }

      let priceText = '';
      const cand = chosen.querySelectorAll('span, div, p');
      for (const el of cand) {
        const tx = el.textContent?.trim() || '';
        if (tx.length > 40) continue;
        if (/[\d.,]+\s*[€£$]|[€£$]\s*[\d.,]+|\bEUR\b|\bUSD\b|\bGBP\b/.test(tx)) {
          priceText = tx;
          break;
        }
      }

      const img = chosen.querySelector('img') as HTMLImageElement | null;
      const imageUrl = img?.currentSrc || img?.src || '';

      seen.add(slug);
      out.push({
        slug,
        listingUrl: absUrl(href),
        title,
        priceText,
        imageUrl,
      });
      if (out.length >= 52) break;
    }
    return out;
  });
}

/**
 * Depop — navigation Playwright + parsing cartes dans le DOM (aucun fetch in-page).
 */
export async function fetchDepopScraperListings(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  const q = searchText.trim();
  const primary = `https://www.depop.com/search/?q=${encodeURIComponent(q)}`;
  console.log('[DEPOP_URL]', primary);

  const browser = await launchChromiumHeadless();
  try {
    const ctx = await browser.newContext({
      userAgent: PLAYWRIGHT_UA,
      locale: 'en-GB',
      viewport: { width: 1365, height: 900 },
      timezoneId: 'Europe/London',
    });
    const page = await ctx.newPage();

    await page.goto(primary, {
      waitUntil: 'domcontentloaded',
      timeout: 55000,
    });

    try {
      await page.waitForLoadState('networkidle', { timeout: 28000 });
    } catch {
      await page.waitForLoadState('load', { timeout: 12000 }).catch(() => {});
    }

    await new Promise((r) => setTimeout(r, 1200));

    console.log('[DEPOP_HTML_READY]', {
      finalUrl: page.url().slice(0, 200),
    });

    let rows = await extractDepopRowsFromDom(page);
    let linkApprox = await page.locator('a[href*="/products/"]').count();
    console.log('[DEPOP_CARDS_COUNT]', {
      productAnchorsApprox: linkApprox,
      parsedRows: rows.length,
    });

    if (rows.length === 0) {
      const fallback = `https://www.depop.com/search/all/?query=${encodeURIComponent(q)}`;
      console.log('[DEPOP_URL]', 'fallback', fallback);
      await page.goto(fallback, { waitUntil: 'domcontentloaded', timeout: 55000 });
      try {
        await page.waitForLoadState('networkidle', { timeout: 22000 });
      } catch {
        await page.waitForLoadState('load', { timeout: 10000 }).catch(() => {});
      }
      await new Promise((r) => setTimeout(r, 1200));
      rows = await extractDepopRowsFromDom(page);
      linkApprox = await page.locator('a[href*="/products/"]').count();
      console.log('[DEPOP_CARDS_COUNT]', {
        productAnchorsApprox: linkApprox,
        parsedRows: rows.length,
        pass: 'fallback',
      });
    }

    const listings: MarketplaceListingDTO[] = [];
    for (const row of rows) {
      const { price, currency } = parseDepopPriceText(row.priceText);
      listings.push({
        id: row.slug,
        source: 'depop',
        title: row.title.slice(0, 500),
        price,
        currency,
        imageUrl: row.imageUrl || undefined,
        thumbnailUrl: row.imageUrl || undefined,
        listingUrl: row.listingUrl,
      });
    }

    console.log('[DEPOP_PARSED_COUNT]', listings.length);

    if (listings.length === 0) {
      const html = await page.content();
      console.log(
        '[DEPOP_HTML_SNIP]',
        html.slice(0, 1500).replace(/\s+/g, ' ')
      );
      throw new Error(
        'depop: 0 cartes produit — sélecteurs DOM ou URL search à ajuster'
      );
    }

    return listings;
  } finally {
    await browser.close();
  }
}
