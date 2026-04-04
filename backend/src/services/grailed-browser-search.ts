import { chromium } from 'playwright';
import type { MarketplaceListingDTO } from '../api/types.js';

const DEFAULT_LIMIT = 20;

function parsePrice(raw: string): { price: number; currency: string } {
  const text = (raw ?? '').trim();
  const currency = text.includes('€') ? 'EUR' : text.includes('£') ? 'GBP' : 'USD';
  const m = text.match(/([\d,.]+(?:\.\d{1,2})?)/);
  if (!m) return { price: 0, currency };
  const price = parseFloat(m[1].replace(/,/g, ''));
  if (!Number.isFinite(price)) return { price: 0, currency };
  return { price, currency };
}

function buildPageUrl(query: string, page: number): string {
  const base = `https://www.grailed.com/shop?query=${encodeURIComponent(query.trim())}`;
  if (page <= 1) return base;
  return `${base}&page=${page}`;
}

export async function searchGrailedByTextBrowser(
  query: string,
  options?: { page?: number; limit?: number }
): Promise<MarketplaceListingDTO[]> {
  const q = query.trim();
  if (!q) return [];
  const pageNumber = Math.max(1, Math.floor(options?.page ?? 1));
  const limit = Math.max(1, Math.floor(options?.limit ?? DEFAULT_LIMIT));

  let browser: Awaited<ReturnType<typeof chromium.launch>> | undefined;
  try {
    browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-dev-shm-usage'],
    });

    const context = await browser.newContext({
      userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
      locale: 'en-US',
    });
    const page = await context.newPage();

    const url = buildPageUrl(q, pageNumber);
    console.log('GRAILED_BROWSER_URL', url);
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });

    const foundGrid = await page
      .waitForSelector('a[href*="/listings/"]', { timeout: 15000 })
      .then(() => true)
      .catch(() => false);
    if (!foundGrid) {
      throw new Error('Grailed listing grid not found (possible anti-bot/challenge)');
    }

    const pageItems = await page.$$eval(
      'div[class*="UserItem_root"]',
      (nodes, maxItems) => {
          const parsePriceInPage = (raw: string): { price: number; currency: string } => {
            const txt = (raw ?? '').trim();
            const currency = txt.includes('€') ? 'EUR' : txt.includes('£') ? 'GBP' : 'USD';
            const m = txt.match(/([\d,.]+(?:\.\d{1,2})?)/);
            if (!m) return { price: 0, currency };
            const n = parseFloat(m[1].replace(/,/g, ''));
            return Number.isFinite(n) ? { price: n, currency } : { price: 0, currency };
          };

          const toAbsolute = (href: string): string => {
            if (!href) return '';
            if (href.startsWith('http://') || href.startsWith('https://')) return href;
            return `https://www.grailed.com${href.startsWith('/') ? '' : '/'}${href}`;
          };

          const extractRelativeDate = (root: HTMLElement): string | undefined => {
            const bySelector = [
              'time',
              '[class*="date"]',
              '[class*="Date"]',
              '[class*="timestamp"]',
              '[class*="time"]',
            ];
            const re =
              /(?:about\s+)?\d+\s+(?:minute|hour|day|week|month|year)s?\s+ago|just now|today|yesterday/i;

            for (const sel of bySelector) {
              const txt = root.querySelector(sel)?.textContent?.trim();
              if (txt && re.test(txt)) return txt;
            }
            const allText = root.textContent?.replace(/\s+/g, ' ').trim() ?? '';
            const m = allText.match(re);
            return m?.[0]?.trim();
          };

          const out: Array<{
            id: string;
            source: string;
            title: string;
            price: number;
            currency: string;
            imageUrl?: string;
            thumbnailUrl?: string;
            listingUrl?: string;
            brand?: string;
            size?: string;
            condition?: string;
            publishedAtRelative?: string;
          }> = [];

          for (const node of nodes) {
            if (out.length >= maxItems) break;
            const root = node as HTMLElement;

            const linkEl = root.querySelector('a[href*="/listings/"]') as HTMLAnchorElement | null;
            const href = linkEl?.getAttribute('href')?.trim() ?? '';
            const listingUrl = toAbsolute(href);
            if (!listingUrl) continue;

            const title =
              root.querySelector('div[class*="UserItem_title"]')?.textContent?.trim() ??
              linkEl?.textContent?.trim() ??
              '';
            if (!title) continue;

            const imgEl = root.querySelector(
              'div[class*="UserItem_listingCoverPhoto"] img, img'
            ) as HTMLImageElement | null;
            const imageUrl =
              imgEl?.getAttribute('src')?.trim() || imgEl?.getAttribute('data-src')?.trim() || undefined;
            if (!imageUrl) continue;

            const brand =
              root.querySelector('div[class*="UserItem_designer"]')?.textContent?.trim() || undefined;
            const size = root.querySelector('div[class*="UserItem_size"]')?.textContent?.trim() || undefined;
            const condition =
              root.querySelector('div[class*="UserItem_condition"]')?.textContent?.trim() || undefined;
            const publishedAtRelative = extractRelativeDate(root);

            const priceText = root.querySelector('span[data-testid="Current"]')?.textContent?.trim() ?? '';
            const parsed = parsePriceInPage(priceText);

            const idMatch = listingUrl.match(/\/listings\/(\d+)/);
            const id = idMatch?.[1] ?? `grailed-${out.length}`;

            out.push({
              id,
              source: 'Grailed',
              title,
              price: parsed.price,
              currency: parsed.currency,
              imageUrl,
              thumbnailUrl: imageUrl,
              listingUrl,
              ...(brand ? { brand } : {}),
              ...(size ? { size } : {}),
              ...(condition ? { condition } : {}),
              ...(publishedAtRelative ? { publishedAtRelative } : {}),
            });
          }

          return out;
        },
      limit
    );

    const normalized: MarketplaceListingDTO[] = [];
    const seen = new Set<string>();
    for (let idx = 0; idx < pageItems.length; idx++) {
      const it = pageItems[idx];
      const listingUrl = it.listingUrl?.trim() ?? '';
      if (!listingUrl || seen.has(listingUrl)) continue;
      seen.add(listingUrl);

      if (it.publishedAtRelative) {
        console.log('[GRAILED_DATE_FOUND]', { listingUrl, raw: it.publishedAtRelative });
      } else {
        console.log('[GRAILED_DATE_ABSENT]', { listingUrl });
      }

      const parsed = parsePrice(String(it.price ?? 0));
      const price = Number.isFinite(it.price) ? Number(it.price) : parsed.price;
      const currency = it.currency?.trim() || parsed.currency || 'USD';
      normalized.push({
        id: it.id || `grailed-${idx}`,
        source: 'Grailed',
        title: it.title?.trim() || 'Grailed listing',
        price: Number.isFinite(price) ? price : 0,
        currency,
        imageUrl: it.imageUrl?.trim(),
        thumbnailUrl: it.thumbnailUrl?.trim() || it.imageUrl?.trim(),
        listingUrl,
        ...(it.brand ? { brand: it.brand } : {}),
        ...(it.size ? { size: it.size } : {}),
        ...(it.condition ? { condition: it.condition } : {}),
        ...(it.publishedAtRelative ? { publishedAtRelative: it.publishedAtRelative } : {}),
      });
    }

    console.log('GRAILED_BROWSER_OK');
    console.log('GRAILED_BROWSER_COUNT', normalized.length);
    return normalized;
  } catch (err) {
    console.error('GRAILED_BROWSER_FAILED', err);
    return [];
  } finally {
    await browser?.close();
  }
}

