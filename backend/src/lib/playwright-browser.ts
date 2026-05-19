/**
 * Navigateur Chromium headless pour requêtes same-origin / contournement 403 fetch serveur.
 * Nécessite `playwright` + `npx playwright install chromium` au déploiement.
 */

export async function loadPlaywrightChromium(): Promise<
  typeof import('playwright')['chromium']
> {
  try {
    const pw = await import('playwright');
    return pw.chromium;
  } catch {
    throw new Error(
      'playwright: module non installé — ajoutez "playwright" aux deps et exécutez `npx playwright install chromium`'
    );
  }
}

export const PLAYWRIGHT_UA =
  process.env.PLAYWRIGHT_USER_AGENT?.trim() ||
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36';

export async function fetchHtmlViaPlaywright(
  url: string,
  opts?: { referer?: string }
): Promise<{ status: number; html: string }> {
  const chromium = await loadPlaywrightChromium();
  const browser = await chromium.launch({ headless: true });
  try {
    const ctx = await browser.newContext({
      userAgent: PLAYWRIGHT_UA,
      locale: 'fr-FR',
      timezoneId: 'Europe/Paris',
      viewport: { width: 1365, height: 900 },
    });
    const page = await ctx.newPage();
    if (opts?.referer) {
      await page.setExtraHTTPHeaders({ Referer: opts.referer });
    }
    const res = await page.goto(url, {
      waitUntil: 'domcontentloaded',
      timeout: 50000,
    });
    const status = res?.status() ?? 0;
    await new Promise((r) => setTimeout(r, 400));
    const html = await page.content();
    return { status, html };
  } finally {
    await browser.close();
  }
}
