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

export interface ProviderStatusDTO {
  provider: string;
  status:
    | 'success'
    | 'disabled'
    | 'rate_limited'
    | 'error'
    | 'timeout'
    | 'skipped'
    | 'blocked'
    | 'blocked_403'
    | 'browser_missing'
    /** En attente côté phase lente (réponse HTTP partielle uniquement). */
    | 'running';
  reason?: string;
  listingsCount?: number;
  durationMs?: number;
  /** Statut HTTP source quand pertinent (scraping). */
  httpStatus?: number;
}

export interface AnalyzeSearchResponseJSON {
  /**
   * partial = providers lents encore en cours (Depop / Grailed / …).
   * completed = toutes les phases terminées pour cette requête.
   */
  status?: 'partial' | 'completed';
  /** Présent si une phase lente est en cours ou pour GET /search-sessions/:id. */
  searchSessionId?: string;
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
  /** État synthétique par provider (ex. { "ebay": "success", "grailed": "blocked" }). */
  providerStatuses?: Record<string, string>;
  /** Raison normalisée pour statuts blocked (ex. grailed_cloudflare). */
  providerStatusReasons?: Record<string, string>;
  /** Message synthétique si aucune annonce n’a été trouvée malgré une vision OK. */
  searchDebugMessage?: string;
}
