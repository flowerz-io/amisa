import type { MarketplaceListingDTO } from '../../types.js';
import { ProviderScrapeError } from '../../lib/provider-scrape-error.js';
import { fetchHtmlViaPlaywright } from '../../lib/playwright-browser.js';

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

/** Parcourt l’arbre JSON pour des objets ressemblant à une annonce Grailed. */
function collectListingLikeObjects(v: unknown, out: Record<string, unknown>[]): void {
  if (!v || typeof v !== 'object') return;
  if (Array.isArray(v)) {
    for (const x of v) collectListingLikeObjects(x, out);
    return;
  }
  const o = v as Record<string, unknown>;
  const hasSlug = typeof o.slug === 'string';
  const hasPrice =
    o.price !== undefined ||
    o.lowest_price !== undefined ||
    o.asking_price !== undefined;
  if (hasSlug && hasTitleish(o) && hasPrice) {
    out.push(o);
    return;
  }
  for (const x of Object.values(o)) collectListingLikeObjects(x, out);
}

function hasTitleish(o: Record<string, unknown>): boolean {
  return (
    typeof o.title === 'string' ||
    typeof o.designer === 'string' ||
    typeof o.name === 'string'
  );
}

function rowToListing(row: Record<string, unknown>): MarketplaceListingDTO | null {
  const slug = typeof row.slug === 'string' ? row.slug : null;
  if (!slug) return null;
  const idRaw = row.id ?? row.listing_id ?? slug;
  const idStr =
    typeof idRaw === 'number'
      ? String(idRaw)
      : typeof idRaw === 'string'
        ? idRaw
        : slug;

  const title =
    (typeof row.title === 'string' && row.title) ||
    (typeof row.designer === 'string' && typeof row.name === 'string'
      ? `${row.designer} — ${row.name}`
      : null) ||
    (typeof row.name === 'string' && row.name) ||
    `Grailed ${idStr.replace(/^l-/, '')}`;

  let price = 0;
  let currency = 'USD';
  const ap = row.asking_price ?? row.lowest_price ?? row.price;
  if (typeof ap === 'number') price = ap;
  else if (typeof ap === 'string') price = Number(ap);
  else if (ap && typeof ap === 'object') {
    const p = ap as Record<string, unknown>;
    const amt = p.amount ?? p.value;
    if (typeof amt === 'number') price = amt;
    if (typeof amt === 'string') price = Number(amt);
    if (typeof p.currency === 'string') currency = p.currency;
  }

  let imageUrl: string | undefined;
  if (Array.isArray(row.pictures) && row.pictures[0]) {
    const p = row.pictures[0] as Record<string, unknown>;
    imageUrl =
      (typeof p.url === 'string' && p.url) ||
      (typeof p.largest === 'string' && (p.largest as string)) ||
      undefined;
  } else if (typeof row.cover_photo_url === 'string') {
    imageUrl = row.cover_photo_url;
  }

  return {
    id: idStr,
    source: 'Grailed',
    title: title.slice(0, 500),
    price: Number.isFinite(price) ? price : 0,
    currency,
    imageUrl,
    thumbnailUrl: imageUrl,
    listingUrl: `https://www.grailed.com/listings/${slug}`,
  };
}

/**
 * Grailed — page / shop + extraction __NEXT_DATA__ (pas de token).
 */
export async function fetchGrailedScraperListings(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  const url = `https://www.grailed.com/shop?query=${encodeURIComponent(searchText)}`;
  const { status, html } = await fetchHtmlViaPlaywright(url, {
    referer: 'https://www.grailed.com/',
  });

  if (status === 403) {
    throw new ProviderScrapeError(
      'grailed: HTTP 403 (origine / bot)',
      403,
      true
    );
  }

  if (
    html.includes('cf-browser-verification') ||
    html.includes('Just a moment') ||
    html.includes('challenge-platform')
  ) {
    throw new ProviderScrapeError(
      'grailed: page protégée Cloudflare',
      403,
      true
    );
  }

  if (!html || status >= 400) {
    throw new Error(`grailed scraper: HTTP ${status} page trop courte`);
  }

  const next = extractNextDataJson(html);
  if (!next) {
    throw new Error(
      'grailed scraper: __NEXT_DATA__ introuvable (anti-bot ou HTML changé)'
    );
  }

  const candidates: Record<string, unknown>[] = [];
  collectListingLikeObjects(next, candidates);

  const seen = new Set<string>();
  const out: MarketplaceListingDTO[] = [];
  for (const row of candidates) {
    const L = rowToListing(row);
    if (!L) continue;
    const k = L.listingUrl ?? `${L.source}|${L.id}`;
    if (seen.has(k)) continue;
    seen.add(k);
    out.push(L);
    if (out.length >= 40) break;
  }

  if (out.length === 0) {
    throw new Error(
      'grailed scraper: aucune annonce extraite (structure JSON évolutive)'
    );
  }
  return out;
}
