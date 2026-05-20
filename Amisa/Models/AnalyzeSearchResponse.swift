//
//  AnalyzeSearchResponse.swift
//  Balibu
//
//  Réponse de l'endpoint POST /analyze-search.
//

import Foundation

/// Réponse complète de l'analyse + recherche.
struct AnalyzeSearchResponse: Decodable {
    /// `partial` tant que Depop / Grailed / … peuvent encore enrichir ; `completed` sinon.
    let status: String?
    /// Présent si `status == partial` — poll `GET /search-sessions/:id`.
    let searchSessionId: String?
    /// Synthèse des providers (ex. `depop`: `running`).
    let providerStatuses: [String: String]?
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

// MARK: - Debug logs (compteurs par source après décodage)

extension AnalyzeSearchResponse {
    /// Logs `[IOS_RESULTS]` — aligné sur le backend `[ANALYZE_RESPONSE]`.
    func logIOSResultsDecoded(context: String) {
        let ebay = listings.filter { MarketplaceSource.canonicalKey(from: $0.source) == "ebay" }.count
        let vinted = listings.filter { MarketplaceSource.canonicalKey(from: $0.source) == "vinted" }.count
        let grailed = listings.filter { MarketplaceSource.canonicalKey(from: $0.source) == "grailed" }.count
        let depop = listings.filter { MarketplaceSource.canonicalKey(from: $0.source) == "depop" }.count
        print("[IOS_RESULTS] context=\(context) total=\(listings.count) ebay=\(ebay) vinted=\(vinted) grailed=\(grailed) depop=\(depop)")
    }
}
