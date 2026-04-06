//
//  VintedListingsAPI.swift
//  Balibu
//
//  POST /vinted-listings — pagination sans ré-analyse vision.
//

import Foundation

struct VintedListingsRequest: Encodable {
    let searchText: String
    let page: Int
}

struct VintedListingsResponse: Decodable {
    let listings: [MarketplaceListingDTO]
    let page: Int
    let hasMore: Bool
}

// MARK: - /search-more (pagination multi-providers)

struct SearchRankingContextDTO: Codable, Hashable {
    let primaryQuery: String
    let probableBrand: String?
    let dominantColor: String?
    let category: String?
    let subcategory: String?
    let dominantItem: String?
    let inferredModel: String?
    let itemTypeCanonical: String?
}

struct ProviderPaginationStateDTO: Codable, Hashable {
    let nextPage: Int
    let hasMore: Bool
    let loadedCount: Int
}

struct SearchPaginationStateDTO: Codable, Hashable {
    let primaryQuery: String
    let batchSizePerProvider: Int
    let vinted: ProviderPaginationStateDTO
    let grailed: ProviderPaginationStateDTO
    let ebay: ProviderPaginationStateDTO?
    let leboncoin: ProviderPaginationStateDTO?
    let depop: ProviderPaginationStateDTO?
}

struct SearchMoreRequest: Encodable {
    let primaryQuery: String
    let batchSizePerProvider: Int?
    let pagination: SearchPaginationStateDTO
    let rankingContext: SearchRankingContextDTO
    /// Aligné sur `/analyze-search` : uniquement les providers activés dans Réglages.
    let enabledProviders: [String]
}

struct SearchMoreResponse: Decodable {
    let listings: [MarketplaceListingDTO]
    let vintedListings: [MarketplaceListingDTO]
    let grailedListings: [MarketplaceListingDTO]
    let ebayListings: [MarketplaceListingDTO]?
    let leboncoinListings: [MarketplaceListingDTO]?
    let depopListings: [MarketplaceListingDTO]?
    let pagination: SearchPaginationStateDTO
    let hasMoreVinted: Bool
    let hasMoreGrailed: Bool
    let hasMoreEbay: Bool?
    let hasMoreLeboncoin: Bool?
    let hasMoreDepop: Bool?
    let providerAvailability: ProviderAvailabilityMapDTO?
}
