//
//  VintedListingsAPI.swift
//  Balibu
//
//  POST /vinted-listings — pagination sans ré-analyse vision.
//

import Foundation

/// Aligné sur le backend `VintedPaginationDTO` / clé JSON `pagination`.
struct VintedPaginationDTO: Codable, Hashable {
    let primaryQuery: String
    let nextPage: Int
    let hasMore: Bool
    let loadedCount: Int
}

struct VintedListingsRequest: Encodable {
    let searchText: String
    let page: Int
}

struct VintedListingsResponse: Decodable {
    let listings: [MarketplaceListingDTO]
    let page: Int
    let hasMore: Bool
}
