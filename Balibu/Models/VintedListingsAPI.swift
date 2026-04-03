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
