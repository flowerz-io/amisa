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
  /** Modèle exact probable (vision expert). */
  exactModel?: string;
  /** Coloris commercial ou descriptif. */
  colorway?: string;
  /** Marque + modèle + coloris (affichage / requête prioritaire). */
  fullIdentification?: string;
  /** Indices visuels courts pour debug / transparence. */
  visualReasoning?: string;
  /** Requêtes Vinted suggérées par le modèle (2–3 idéalement). */
  searchQueries?: string[];
}

export interface AnalyzeSearchBody {
  imageBase64?: string;
  textQuery?: string;
  /**
   * Conservé pour compat clients ; seul `vinted` est pris en compte côté serveur.
   * Si absent ou vide, équivalent à `["vinted"]`.
   */
  enabledProviders?: string[];
}

/** Pagination Vinted après la première fusion (requête texte principale). */
export interface VintedPaginationDTO {
  primaryQuery: string;
  nextPage: number;
  hasMore: boolean;
  loadedCount: number;
}

export interface AnalyzeSearchResponseJSON {
  status?: 'completed';
  searchSessionId?: string;
  visionResult: FashionVisionResult;
  generatedQueries: string[];
  listings: MarketplaceListingDTO[];
  pagination?: VintedPaginationDTO;
  vintedSearchFailed?: boolean;
  initialResponseTimeMs?: number;
  /** Message si aucune annonce ou provider indisponible. */
  searchDebugMessage?: string;
}
