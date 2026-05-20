//
//  SearchSessionRemoteModels.swift
//  Balibu
//

import Foundation

struct StartSearchSessionResponse: Decodable {
    let sessionId: String
    let status: String
    let searchQuery: String?
}

struct SearchSessionPollResponse: Decodable {
    let sessionId: String
    let status: String
    let searchQuery: String?
    let error: String?
    let response: AnalyzeSearchResponse?
    let listings: [MarketplaceListingDTO]?
}
