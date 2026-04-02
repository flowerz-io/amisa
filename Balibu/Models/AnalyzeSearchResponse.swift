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

    init(visionResult: FashionVisionResult, generatedQueries: [String], listings: [MarketplaceListingDTO]) {
        self.visionResult = visionResult
        self.generatedQueries = generatedQueries
        self.listings = listings
    }
}
