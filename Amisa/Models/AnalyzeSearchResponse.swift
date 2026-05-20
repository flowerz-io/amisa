//
//  AnalyzeSearchResponse.swift
//  Balibu
//
//  Réponse de l'endpoint POST /analyze-search.
//

import Foundation

/// Réponse complète de l'analyse + recherche Vinted.
struct AnalyzeSearchResponse: Decodable {
    let status: String?
    let searchSessionId: String?
    let visionResult: FashionVisionResult
    let generatedQueries: [String]
    let listings: [MarketplaceListingDTO]
    let pagination: VintedPaginationDTO?
    let vintedSearchFailed: Bool?
    let initialResponseTimeMs: Int?
    let searchDebugMessage: String?
}

extension AnalyzeSearchResponse {
    func logIOSResultsDecoded(context: String) {
        let n = listings.count
        print("[IOS_RESULTS] context=\(context) total=\(n) (Vinted)")
    }
}
