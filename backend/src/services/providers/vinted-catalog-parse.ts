import type { MarketplaceListingDTO } from '../../types.js';

/**
 * Parse la réponse JSON `catalog/items` Vinted (items[]).
 * Lance si code !== 0 avec message sans référence « jeton invalide ».
 */
export function parseVintedCatalogPayload(
  data: unknown,
  httpStatus: number
): MarketplaceListingDTO[] {
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

  return out;
}
