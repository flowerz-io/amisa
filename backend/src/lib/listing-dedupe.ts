import type { MarketplaceListingDTO } from '../types.js';

/**
 * Clé stable : source + id (identifiant marketplace) ; repli source + URL ; sinon repli legacy.
 */
export function marketplaceListingDedupeKey(L: MarketplaceListingDTO): string {
  const src = (L.source ?? '').trim().toLowerCase();
  const extId = (L.id ?? '').trim();
  if (src && extId) return `ext:${src}|${extId}`;
  const url = L.listingUrl?.trim();
  if (src && url) return `url:${src}|${url}`;
  if (url) return `url:${url}`;
  return `id:${src}|${extId}`;
}
