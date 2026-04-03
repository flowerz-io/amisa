/**
 * Types API alignés avec les modèles Swift (camelCase).
 * Contrat backend Balibu MVP.
 */

// --- POST /analyze-search ---

export interface AnalyzeSearchRequest {
  imageBase64: string;
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
}

export interface MarketplaceListingDTO {
  id: string;
  source: string;
  title: string;
  price: number;
  currency?: string;
  imageUrl?: string;
  thumbnailUrl?: string;
  listingUrl?: string;
  /** Marque affichée sur la carte (ex. Vinted) */
  brand?: string;
  size?: string;
  condition?: string;
}

export interface AnalyzeSearchResponse {
  visionResult: FashionVisionResult;
  generatedQueries: string[];
  listings: MarketplaceListingDTO[];
  /** Présent uniquement quand DEBUG=1 ou NODE_ENV=development */
  debug?: {
    visionProvider: string;
    rawVisionOutput: string | object;
    normalizedVisionResult: FashionVisionResult;
    generatedSearchQueries: string[];
  };
}

// --- POST /resolve-shared-url ---

export interface ResolveSharedUrlRequest {
  url: string;
}

export interface ResolveSharedUrlResponse {
  imageBase64: string;
  sourceUrl?: string;
}

export interface ResolveSharedUrlErrorResponse {
  error: string;
  message: string;
}
