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

    init(
        visionResult: FashionVisionResult,
        generatedQueries: [String],
        listings: [MarketplaceListingDTO],
        pagination: SearchPaginationStateDTO? = nil,
        rankingContext: SearchRankingContextDTO? = nil,
        vintedSearchFailed: Bool? = nil,
        grailedSearchFailed: Bool? = nil,
        ebaySearchFailed: Bool? = nil,
        leboncoinSearchFailed: Bool? = nil,
        depopSearchFailed: Bool? = nil
    ) {
        self.visionResult = visionResult
        self.generatedQueries = generatedQueries
        self.listings = listings
        self.pagination = pagination
        self.rankingContext = rankingContext
        self.vintedSearchFailed = vintedSearchFailed
        self.grailedSearchFailed = grailedSearchFailed
        self.ebaySearchFailed = ebaySearchFailed
        self.leboncoinSearchFailed = leboncoinSearchFailed
        self.depopSearchFailed = depopSearchFailed
    }
}
