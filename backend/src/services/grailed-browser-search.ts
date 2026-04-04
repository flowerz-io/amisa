import { chromium } from 'playwright';
import type { MarketplaceListingDTO } from '../api/types.js';

const MAX_ITEMS = 20;

function parsePrice(raw: string): { price: number; currency: string } {
  const text = (raw ?? '').trim();
  const currency = text.includes('€') ? 'EUR' : text.includes('£') ? 'GBP' : 'USD';
  const m = text.match(/([\d,.]+(?:\.\d{1,2})?)/);
  if (!m) return { price: 0, currency };
  const price = parseFloat(m[1].replace(/,/g, ''));
  if (!Number.isFinite(price)) return { price: 0, currency };
  return { price, currency };
}

export async function searchGrailedByTextBrowser(query: string): Promise<MarketplaceListingDTO[]> {
  const q = query.trim();
  if (!q) return [];

  const url = `https://www.grailed.com/shop?query=${encodeURIComponent(q)}`;
  console.log('GRAILED_BROWSER_URL', url);

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

    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.waitForSelector('a[href*="/listings/"]', { timeout: 20000 });

    const scraped = await page.$$eval(
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
          const imageUrl = imgEl?.getAttribute('src')?.trim() || imgEl?.getAttribute('data-src')?.trim() || undefined;
          if (!imageUrl) continue;

          const brand =
            root.querySelector('div[class*="UserItem_designer"]')?.textContent?.trim() || undefined;
          const size = root.querySelector('div[class*="UserItem_size"]')?.textContent?.trim() || undefined;
          const condition =
            root.querySelector('div[class*="UserItem_condition"]')?.textContent?.trim() ||
            undefined;

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
          });
        }

        return out;
      },
      MAX_ITEMS
    );

    // Sécurité côté Node : normalisation stricte DTO.
    const listings: MarketplaceListingDTO[] = scraped.map((it, idx) => {
      const id = it.id || `grailed-${idx}`;
      const listingUrl = it.listingUrl?.trim() ?? '';
      const title = it.title?.trim() ?? '';
      const imageUrl = it.imageUrl?.trim() ?? '';
      const parsed = parsePrice(String(it.price ?? 0));
      const price = Number.isFinite(it.price) ? Number(it.price) : parsed.price;
      const currency = it.currency?.trim() || parsed.currency || 'USD';
      return {
        id,
        source: 'Grailed',
        title: title || 'Grailed listing',
        price: Number.isFinite(price) ? price : 0,
        currency,
        imageUrl,
        thumbnailUrl: it.thumbnailUrl?.trim() || imageUrl,
        listingUrl,
        ...(it.brand ? { brand: it.brand } : {}),
        ...(it.size ? { size: it.size } : {}),
        ...(it.condition ? { condition: it.condition } : {}),
      };
    });

    console.log('GRAILED_BROWSER_OK');
    console.log('GRAILED_BROWSER_COUNT', listings.length);
    return listings.slice(0, MAX_ITEMS);
  } catch (err) {
    console.error('GRAILED_BROWSER_FAILED', err);
    return [];
  } finally {
    await browser?.close();
  }
}

