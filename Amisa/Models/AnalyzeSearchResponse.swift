//
//  AnalyzeSearchResponse.swift
//  Balibu
//
//  Réponse de l'endpoint POST /analyze-search.
//

import Foundation

/// Réponse complète de l'analyse + recherche.
struct AnalyzeSearchResponse: Decodable {
    let visionResult: FashionVisionResult
    let generatedQueries: [String]
    let listings: [MarketplaceListingDTO]
    let pagination: SearchPaginationStateDTO?
    let rankingContext: SearchRankingContextDTO?
    /// Présent si le catalogue Vinted n’a pas pu être chargé malgré une vision OK.
    let vintedSearchFailed: Bool?
    let grailedSearchFailed: Bool?
    let ebaySearchFailed: Bool?
    let leboncoinSearchFailed: Bool?
    let depopSearchFailed: Bool?
    let providerAvailability: ProviderAvailabilityMapDTO?
    let initialResponseTimeMs: Int?
    let providerCounts: ProviderCountsDTO?
    /// Réponse « vague » : d’autres sources marketplace n’étaient pas encore toutes intégrées au snapshot (early cutoff côté serveur).
    let moreProvidersPending: Bool?
    /// Message explicatif si aucune annonce (ex. résumé des erreurs providers côté Railway).
    let searchDebugMessage: String?
}
