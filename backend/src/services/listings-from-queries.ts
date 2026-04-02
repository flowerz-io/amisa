import type { MarketplaceListingDTO } from '../api/types.js';

const SOURCES = ['Grailed', 'Vinted', 'Depop', 'Vestiaire'];
const CURRENCIES = ['EUR', 'GBP', 'USD'];
const SIZES = ['S', 'M', 'L', '36', '38', '40', '41', '42'];
const CONDITIONS = ['Like new', 'Very good', 'Good', 'Excellent'];
const IMAGE_BASE = 'https://images.unsplash.com';

const STOCK_IMAGES: string[] = [
  `${IMAGE_BASE}/photo-1543163521-1bf539c55dd2?w=400`,
  `${IMAGE_BASE}/photo-1594938298603-c8148c4dae35?w=400`,
  `${IMAGE_BASE}/photo-1590874103328-eac38a683ce7?w=400`,
  `${IMAGE_BASE}/photo-1551028719-00167b16eac5?w=400`,
  `${IMAGE_BASE}/photo-1558171813-4c088753af8f?w=400`
];

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)] ?? arr[0];
}

function slugify(query: string, suffix: string): string {
  const slug = query.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
  return `${slug}-${suffix}`;
}

/**
 * Génère des listings mockés à partir des queries.
 * Chaque listing a thumbnailUrl, imageUrl, price (number), etc.
 */
export function generateListingsFromQueries(
  queries: string[],
  count: number = 8
): MarketplaceListingDTO[] {
  const listings: MarketplaceListingDTO[] = [];
  const usedIds = new Set<string>();

  for (let i = 0; i < count; i++) {
    const query = queries[i % queries.length] ?? queries[0];
    const source = pick(SOURCES);
    const img = pick(STOCK_IMAGES);
    const baseId = `${source.toLowerCase().slice(0, 2)}-${i}`;
    let id = baseId;
    let j = 0;
    while (usedIds.has(id)) {
      j++;
      id = `${baseId}-${j}`;
    }
    usedIds.add(id);

    const price = Math.round(80 + Math.random() * 420);
    const currency = pick(CURRENCIES);
    const title = query.length > 40
      ? query.slice(0, 40) + '...'
      : query;

    listings.push({
      id,
      source,
      title: `${title} - ${pick(CONDITIONS)}`,
      price,
      currency,
      imageUrl: img,
      thumbnailUrl: img.replace('w=400', 'w=120'),
      listingUrl: `https://${source.toLowerCase()}.com/items/${slugify(query, id)}`,
      size: pick(SIZES),
      condition: pick(CONDITIONS)
    });
  }

  return listings;
}
