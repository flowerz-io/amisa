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
    /// Présent lorsque `status == completed` (corps GET Railway).
    let response: AnalyzeSearchResponse?
}
