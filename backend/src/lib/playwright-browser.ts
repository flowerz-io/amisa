/**
 * Navigateur Chromium headless pour requêtes same-origin / contournement 403 fetch serveur.
 * En prod Railway : Dockerfile installe Chromium via `npx playwright install --with-deps chromium`.
 */

import fs from 'node:fs';

export class PlaywrightChromiumMissingError extends Error {
  override readonly name = 'PlaywrightChromiumMissingError';
  constructor(message: string) {
    super(message);
  }
}

export async function loadPlaywrightChromium(): Promise<
  typeof import('playwright')['chromium']
> {
  try {
    const pw = await import('playwright');
    return pw.chromium;
  } catch {
    throw new PlaywrightChromiumMissingError(
      'playwright: module npm non installé ou import impossible'
    );
  }
}

/**
 * Log startup : chemins Playwright/Chromium utilisables par le runtime.
 */
export async function logPlaywrightReadinessAtStartup(): Promise<void> {
  try {
    const chromiumMod = await loadPlaywrightChromium();
    const exe = chromiumMod.executablePath();
    const exists = fs.existsSync(exe);
    if (exists) {
      console.log(`[PLAYWRIGHT_READY] chromium executable path = ${exe}`);
      console.log(
        '[PLAYWRIGHT_READY] PLAYWRIGHT_BROWSERS_PATH =',
        process.env.PLAYWRIGHT_BROWSERS_PATH ?? '<unset>'
      );
      return;
    }
    console.warn(
      `[PLAYWRIGHT_READY] chromium manquant au chemin: ${exe} — prévoir Dockerfile / npx playwright install --with-deps chromium`
    );
  } catch (e) {
    const msg = e instanceof PlaywrightChromiumMissingError ? e.message : e instanceof Error ? e.message : String(e);
    console.warn('[PLAYWRIGHT_READY] chromium indisponible:', msg);
  }
}

export async function launchChromiumHeadless(): Promise<
  import('playwright').Browser
> {
  const chromiumLib = await loadPlaywrightChromium();
  const exe = chromiumLib.executablePath();
  if (!fs.existsSync(exe)) {
    throw new PlaywrightChromiumMissingError(
      `chromium absent dans le runtime (attendu: ${exe}); exécuter: npx playwright install --with-deps chromium`
    );
  }
  try {
    return await chromiumLib.launch({
      headless: true,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const low = msg.toLowerCase();
    if (
      low.includes(`executable doesn't exist`) ||
      low.includes('executable does not exist') ||
      (low.includes('browser') &&
        low.includes('launch') &&
        low.includes('not found'))
    ) {
      throw new PlaywrightChromiumMissingError(msg);
    }
    throw e;
  }
}

export const PLAYWRIGHT_UA =
  process.env.PLAYWRIGHT_USER_AGENT?.trim() ||
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36';

export async function fetchHtmlViaPlaywright(
  url: string,
  opts?: { referer?: string }
): Promise<{ status: number; html: string }> {
  const browser = await launchChromiumHeadless();
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
