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
    /// Snapshot complet (y compris `status` partiel / terminé).
    let response: AnalyzeSearchResponse?
    /// Raccourcis alignés sur le contrat API (GET).
    let listings: [MarketplaceListingDTO]?
    let providerStatuses: [String: String]?
}
