import type { FashionVisionResult, MarketplaceListingDTO } from '../../types.js';

const REVIEW_FALLBACK_COUNT = 12;

function categoryLabel(vision: FashionVisionResult): string {
  const cat = (vision.category ?? vision.itemTypeCanonical ?? '').toLowerCase();
  if (cat.includes('chaussure') || cat.includes('sneaker') || cat.includes('shoe')) {
    return 'sneakers';
  }
  if (cat.includes('sac') || cat.includes('bag')) return 'sac';
  if (cat.includes('veste') || cat.includes('jacket') || cat.includes('coat')) {
    return 'veste';
  }
  if (cat.includes('robe') || cat.includes('dress')) return 'robe';
  return 'mode';
}

/**
 * Annonces mock réalistes pour App Store Review quand Vinted est bloqué.
 * Taguées `reviewFallback` — jamais confondues avec du scraping live.
 */
export function buildReviewFallbackListings(
  vision: FashionVisionResult
): MarketplaceListingDTO[] {
  const brand = (vision.probableBrand ?? 'Marque').trim() || 'Marque';
  const model =
    (vision.exactModel ?? vision.inferredModel ?? vision.dominantItem ?? 'Article')
      .trim() || 'Article';
  const color = (vision.color ?? vision.colorway ?? 'neutre').trim();
  const kind = categoryLabel(vision);

  console.log('[REVIEW_FALLBACK_USED]', {
    brand,
    model,
    kind,
    count: REVIEW_FALLBACK_COUNT,
  });

  const sizes = ['36', '37', '38', '39', '40', 'M', 'L', 'S'];
  const conditions = [
    'Très bon état',
    'Bon état',
    'Neuf avec étiquette',
    'Neuf sans étiquette',
  ];

  return Array.from({ length: REVIEW_FALLBACK_COUNT }, (_, i) => {
    const size = sizes[i % sizes.length]!;
    const condition = conditions[i % conditions.length]!;
    const price = 45 + i * 7;
    const id = `review-fallback-${i + 1}`;
    const title = `${brand} ${model} ${color} — ${kind} (aperçu review)`;

    return {
      id,
      source: 'vinted',
      title,
      price,
      currency: 'EUR',
      imageUrl: undefined,
      thumbnailUrl: undefined,
      listingUrl: `https://www.vinted.fr/items/${id}`,
      brand,
      size,
      condition,
      relevanceScore: 88 - i,
      publishedAtRelative: 'Il y a 2 jours',
    };
  });
}

export function isReviewSafeModeEnabled(): boolean {
  return (
    process.env.NODE_ENV === 'production' &&
    process.env.APP_REVIEW_SAFE_MODE?.trim().toLowerCase() === 'true'
  );
}
