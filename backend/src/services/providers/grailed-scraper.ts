import type { MarketplaceListingDTO } from '../../types.js';
import { fetchHtmlViaPlaywright } from '../../lib/playwright-browser.js';
import { GrailedBlockedError } from './grailed-blocked.js';

function extractNextDataJson(html: string): unknown | null {
  const m = html.match(
    /<script id="__NEXT_DATA__" type="application\/json">([^<]+)<\/script>/
  );
  if (!m?.[1]) return null;
  try {
    return JSON.parse(m[1]);
  } catch {
    return null;
  }
}

function readDesignerName(row: Record<string, unknown>): string | undefined {
  const d = row.designer;
  if (typeof d === 'string' && d.trim()) return d.trim();
  if (d && typeof d === 'object') {
    const o = d as Record<string, unknown>;
    if (typeof o.name === 'string' && o.name.trim()) return o.name.trim();
  }
  if (typeof row.designer_name === 'string' && row.designer_name.trim()) {
    return row.designer_name.trim();
  }
  return undefined;
}

function grailedSlugFromRow(row: Record<string, unknown>): string | null {
  if (typeof row.slug === 'string' && row.slug.length > 0) return row.slug;
  for (const k of ['url', 'href', 'path', 'permalink'] as const) {
    const u = row[k];
    if (typeof u !== 'string') continue;
    const m = u.match(/\/listings\/([^/?#]+)/);
    if (m?.[1]) return m[1];
  }
  return null;
}

function extractGrailedMoney(
  row: Record<string, unknown>
): { price: number; currency: string } {
  let price = 0;
  let currency = 'USD';
  const candidates = [
    row.asking_price,
    row.lowest_price,
    row.price,
    row.sold_price,
    row.listing_price,
  ];
  for (const ap of candidates) {
    if (ap == null) continue;
    if (typeof ap === 'number') {
      price = ap;
      break;
    }
    if (typeof ap === 'string') {
      const n = Number(ap);
      if (Number.isFinite(n)) {
        price = n;
        break;
      }
    }
    if (typeof ap === 'object') {
      const p = ap as Record<string, unknown>;
      const amt = p.amount ?? p.value ?? p.price_amount;
      if (typeof amt === 'number') price = amt;
      else if (typeof amt === 'string') price = Number(amt);
      if (typeof p.currency === 'string') currency = String(p.currency).toUpperCase();
      if (typeof p.currency_code === 'string') {
        currency = String(p.currency_code).toUpperCase();
      }
      if (Number.isFinite(price) && price > 0) break;
    }
  }
  return { price: Number.isFinite(price) ? price : 0, currency };
}

function rowHasListingTitle(row: Record<string, unknown>): boolean {
  const bits = [
    typeof row.title === 'string' ? row.title : '',
    typeof row.name === 'string' ? row.name : '',
    typeof row.short_description === 'string' ? row.short_description : '',
    readDesignerName(row) ?? '',
  ];
  return bits.some((s) => s.trim().length > 0);
}

function looksLikeGrailedListing(row: Record<string, unknown>): boolean {
  const slug = grailedSlugFromRow(row);
  if (!slug) return false;
  if (!rowHasListingTitle(row)) return false;
  const { price } = extractGrailedMoney(row);
  if (Number.isFinite(price) && price > 0) return true;
  if (
    row.asking_price != null ||
    row.price != null ||
    row.lowest_price != null ||
    row.listing_price != null
  ) {
    return true;
  }
  return false;
}

function walkGrailedCandidates(
  v: unknown,
  out: Record<string, unknown>[],
  depth: number
): void {
  if (depth > 32 || !v || typeof v !== 'object') return;
  if (Array.isArray(v)) {
    for (const x of v) walkGrailedCandidates(x, out, depth + 1);
    return;
  }
  const o = v as Record<string, unknown>;
  if (looksLikeGrailedListing(o)) {
    out.push(o);
    return;
  }
  for (const x of Object.values(o)) {
    walkGrailedCandidates(x, out, depth + 1);
  }
}

function rowToListing(row: Record<string, unknown>): MarketplaceListingDTO | null {
  const slug = grailedSlugFromRow(row);
  if (!slug) return null;

  const idRaw = row.id ?? row.listing_id ?? slug;
  const idStr =
    typeof idRaw === 'number'
      ? String(idRaw)
      : typeof idRaw === 'string'
        ? idRaw
        : slug;

  const designer = readDesignerName(row);
  const title =
    (typeof row.title === 'string' && row.title) ||
    (designer && typeof row.name === 'string'
      ? `${designer} — ${row.name}`
      : null) ||
    (typeof row.name === 'string' && row.name) ||
    (typeof row.short_description === 'string' && row.short_description) ||
    `grailed ${slug}`;

  const { price, currency } = extractGrailedMoney(row);

  let imageUrl: string | undefined;
  if (Array.isArray(row.pictures) && row.pictures[0]) {
    const p = row.pictures[0] as Record<string, unknown>;
    imageUrl =
      (typeof p.url === 'string' && p.url) ||
      (typeof p.largest === 'string' && (p.largest as string)) ||
      (typeof p.small === 'string' && (p.small as string)) ||
      undefined;
  }
  if (!imageUrl && typeof row.cover_photo_url === 'string') {
    imageUrl = row.cover_photo_url;
  }
  if (!imageUrl && typeof row.hero_image_url === 'string') {
    imageUrl = row.hero_image_url;
  }

  return {
    id: idStr,
    source: 'grailed',
    title: title.slice(0, 500),
    price: Number.isFinite(price) ? price : 0,
    currency,
    imageUrl,
    thumbnailUrl: imageUrl,
    listingUrl: `https://www.grailed.com/listings/${slug}`,
  };
}

function isCloudflareChallengeHtml(html: string): boolean {
  return (
    html.includes('cf-browser-verification') ||
    html.includes('Just a moment') ||
    html.includes('challenge-platform')
  );
}

/**
 * Grailed — HTML shop + __NEXT_DATA__ si disponible.
 * Cloudflare / 403 : erreur dédiée (pas d’échec HTTP global du pipeline).
 */
export async function fetchGrailedScraperListings(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  const url = `https://www.grailed.com/shop?query=${encodeURIComponent(searchText)}`;

  const { status, html } = await fetchHtmlViaPlaywright(url, {
    referer: 'https://www.grailed.com/',
    settleMs: 2200,
  });

  if (status === 403 || isCloudflareChallengeHtml(html)) {
    throw new GrailedBlockedError('grailed_cloudflare');
  }

  if (!html || status >= 400) {
    throw new GrailedBlockedError('grailed_cloudflare');
  }

  const next = extractNextDataJson(html);
  if (!next) {
    throw new Error(
      'grailed scraper: __NEXT_DATA__ introuvable (HTML changé ou blocage léger)'
    );
  }

  const candidates: Record<string, unknown>[] = [];
  walkGrailedCandidates(next, candidates, 0);

  const seen = new Set<string>();
  const out: MarketplaceListingDTO[] = [];
  for (const row of candidates) {
    const L = rowToListing(row);
    if (!L) continue;
    const k = L.listingUrl ?? `grailed|${L.id}`;
    if (seen.has(k)) continue;
    seen.add(k);
    out.push(L);
    if (out.length >= 40) break;
  }

  if (out.length === 0) {
    throw new Error(
      'grailed scraper: aucune annonce extraite (__NEXT_DATA__ sans listings reconnus)'
    );
  }
  return out;
}

export { GrailedBlockedError } from './grailed-blocked.js';
