//
//  SearchSessionStatusService.swift
//  Balibu
//
//  Accès au statut de session Railway (source de vérité).
//

import Foundation

enum SearchSessionStatusService {
    static func fetchStatus(sessionId: String, apiClient: APIClientProtocol) async throws -> SearchSessionPollResponse {
        try await apiClient.fetchSearchSessionStatus(sessionId: sessionId)
    }
}
