/** Aligné sur `MarketplaceListingDTO` (Swift). */
export interface MarketplaceListingDTO {
  id: string;
  source: string;
  title: string;
  price: number;
  currency?: string;
  imageUrl?: string;
  thumbnailUrl?: string;
  listingUrl?: string;
  brand?: string;
  size?: string;
  condition?: string;
  publishedAtRelative?: string;
  relevanceScore?: number;
}

export interface FashionVisionResult {
  category?: string;
  subcategory?: string;
  dominantItem?: string;
  probableBrand?: string;
  color?: string;
  material?: string;
  styleKeywords?: string[];
  confidence?: number;
  sourceConfidence?: number;
  inferredEntity?: string;
  secondaryMarking?: string;
  inferredModel?: string;
  dominantColorPrecise?: string;
  itemTypeCanonical?: string;
}

export interface AnalyzeSearchBody {
  imageBase64?: string;
  textQuery?: string;
  enabledProviders: string[];
}

export interface AnalyzeSearchResponseJSON {
  visionResult: FashionVisionResult;
  generatedQueries: string[];
  listings: MarketplaceListingDTO[];
  pagination?: unknown;
  rankingContext?: unknown;
  vintedSearchFailed?: boolean;
  grailedSearchFailed?: boolean;
  ebaySearchFailed?: boolean;
  leboncoinSearchFailed?: boolean;
  depopSearchFailed?: boolean;
  providerAvailability?: unknown;
  initialResponseTimeMs?: number;
  providerCounts?: unknown;
  /** Vrai si la réponse est une vague partielle (d’autres providers pourraient encore fusionner côté serveur — ici une seule réponse HTTP). */
  moreProvidersPending?: boolean;
}
