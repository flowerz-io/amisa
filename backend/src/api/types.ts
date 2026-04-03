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
  /** Description courte factuelle de l’objet (pas une search query). */
  dominantItem?: string;
  probableBrand?: string;
  /** Couleur héritée / secours ; préférer dominantColorPrecise pour la query. */
  color?: string;
  material?: string;
  styleKeywords?: string[];
  confidence?: number;
  sourceConfidence?: number;
  /** Équipe, club, franchise, univers logo (ex: Mets, Yankees). Omis si incertain. */
  inferredEntity?: string;
  /** Collaboration ou texte secondaire utile (ex: MoMA). Omis si absent ou incertain. */
  secondaryMarking?: string;
  /** Modèle reconnaissable (ex: Detroit Jacket, Boston). Omis si trop incertain. */
  inferredModel?: string;
  /** Couleur dominante réelle de l’item (~80 % surface), un seul terme simple. */
  dominantColorPrecise?: string;
  /** Type canon court pour désambiguïser (ex: jacket, cap, clog, sneaker). */
  itemTypeCanonical?: string;
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
