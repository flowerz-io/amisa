import type { MarketplaceListingDTO } from '../../types.js';

function perPageFromEnv(): number {
  const n = Number(process.env.VINTED_SCRAPER_PER_PAGE?.trim() || '24');
  return Number.isFinite(n) && n > 0 ? n : 24;
}

/**
 * Déduit s'il existe une page suivante sur le catalogue Vinted.
 */
export function vintedCatalogHasMore(
  data: unknown,
  itemsLength: number,
  perPage: number
): boolean {
  const root = data as Record<string, unknown>;
  const pag = root.pagination;
  if (pag && typeof pag === 'object' && !Array.isArray(pag)) {
    const p = pag as Record<string, unknown>;
    const cur = p.current_page ?? p.currentPage;
    const total = p.total_pages ?? p.totalPages;
    if (typeof cur === 'number' && typeof total === 'number') {
      return cur < total;
    }
    const totalEntries = p.total_entries ?? p.totalEntries;
    const per = Number(p.per_page ?? p.perPage ?? perPage);
    if (
      typeof totalEntries === 'number' &&
      typeof cur === 'number' &&
      Number.isFinite(per) &&
      per > 0
    ) {
      return cur * per < totalEntries;
    }
  }
  return itemsLength >= perPage;
}

export interface VintedCatalogParseResult {
  listings: MarketplaceListingDTO[];
  hasMore: boolean;
}

/**
 * Parse la réponse JSON `catalog/items` Vinted (items[]) + pagination.
 */
export function parseVintedCatalogResponse(
  data: unknown,
  httpStatus: number
): VintedCatalogParseResult {
  const root = data as Record<string, unknown>;

  if (typeof root.code === 'number' && root.code !== 0) {
    const msg =
      typeof root.message === 'string' ? root.message : 'erreur_inconnue';
    if (root.code === 100) {
      throw new Error(
        `vinted: le catalogue ne répond pas sans session (code ${root.code}, protection Vintéd / anti-bot)`
      );
    }
    throw new Error(
      `vinted: réponse catalogue refusée HTTP ${httpStatus} (${root.code}: ${msg.slice(0, 120)})`
    );
  }

  const items = root.items;
  if (!Array.isArray(items)) {
    throw new Error(
      `vinted: format inattendu (pas d'items[]) HTTP ${httpStatus}`
    );
  }

  const perPage = perPageFromEnv();
  const out: MarketplaceListingDTO[] = [];
  for (const raw of items) {
    if (!raw || typeof raw !== 'object') continue;
    const row = raw as Record<string, unknown>;
    const id = row.id;
    const idStr =
      typeof id === 'number'
        ? String(id)
        : typeof id === 'string'
          ? id
          : undefined;
    if (!idStr) continue;

    const title =
      typeof row.title === 'string' ? row.title : `Vinted ${idStr}`;
    let price = 0;
    let currency = 'EUR';
    const p = row.price;
    if (p && typeof p === 'object' && !Array.isArray(p)) {
      const po = p as Record<string, unknown>;
      const amt = po.amount;
      if (typeof amt === 'string' || typeof amt === 'number') {
        price = Number(amt);
      }
      const cur = po.currency_code;
      if (typeof cur === 'string') currency = cur;
    }

    let photo: string | undefined;
    const photos = row.photo;
    if (photos && typeof photos === 'object' && !Array.isArray(photos)) {
      const ph = photos as Record<string, unknown>;
      const url = ph.url;
      if (typeof url === 'string') photo = url;
    }

    const urlVal = row.url;
    const listingUrl =
      typeof urlVal === 'string'
        ? urlVal.startsWith('http')
          ? urlVal
          : `https://www.vinted.fr${urlVal}`
        : `https://www.vinted.fr/items/${idStr}`;

    out.push({
      id: idStr,
      source: 'vinted',
      title,
      price: Number.isFinite(price) ? price : 0,
      currency,
      imageUrl: photo,
      thumbnailUrl: photo,
      listingUrl,
    });
  }

  return {
    listings: out,
    hasMore: vintedCatalogHasMore(data, out.length, perPage),
  };
}

/** @deprecated Préférer parseVintedCatalogResponse pour obtenir hasMore. */
export function parseVintedCatalogPayload(
  data: unknown,
  httpStatus: number
): MarketplaceListingDTO[] {
  return parseVintedCatalogResponse(data, httpStatus).listings;
}
