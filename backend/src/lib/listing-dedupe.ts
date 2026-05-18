import type { MarketplaceListingDTO } from '../types.js';

/** Clé stable pour dédoublonner (URL canonique si présente, sinon source + id). */
export function marketplaceListingDedupeKey(L: MarketplaceListingDTO): string {
  const url = L.listingUrl?.trim();
  if (url) return `url:${url}`;
  const src = (L.source ?? '').toLowerCase();
  return `id:${src}|${L.id}`;
}
