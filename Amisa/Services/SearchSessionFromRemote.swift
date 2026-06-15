//
//  SearchSessionFromRemote.swift
//  Balibu
//

import Foundation
import UIKit

enum SearchSessionFromRemote {
    static func providerFields(from response: AnalyzeSearchResponse) -> (
        providerUnavailable: Bool,
        providerUnavailableMessage: String?,
        reviewFallback: Bool
    ) {
        let unavailable = response.isProviderUnavailable
            || response.searchDebugMessage == "provider_unavailable"
        let message = response.message
            ?? (unavailable ? String(localized: "Les résultats sont temporairement indisponibles.") : nil)
        return (
            providerUnavailable: unavailable,
            providerUnavailableMessage: message,
            reviewFallback: response.reviewFallback ?? false
        )
    }

    @MainActor
    static func buildSession(
        response: AnalyzeSearchResponse,
        imageFileName: String?
    ) -> SearchSession {
        let primaryQuery: String = {
            if let q = response.generatedQueries.first?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
                return q
            }
            if let p = response.pagination?.primaryQuery.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
                return p
            }
            return ""
        }()
        let listings = response.listings.map { MarketplaceListing.from($0) }
        let provider = providerFields(from: response)

        var session = SearchSession(
            id: UUID(),
            imageFileName: imageFileName,
            thumbnailImageURL: nil,
            searchQuery: primaryQuery,
            generatedQueries: response.generatedQueries,
            attributes: response.visionResult,
            listings: listings,
            createdAt: Date(),
            vintedSearchFailed: response.vintedSearchFailed ?? false,
            vintedPagination: response.pagination,
            initialResponseTimeMs: response.initialResponseTimeMs,
            searchDebugMessage: response.searchDebugMessage,
            noRelevantResults: response.noRelevantResults ?? (response.searchDebugMessage == "no_relevant_results"),
            providerUnavailable: provider.providerUnavailable,
            providerUnavailableMessage: provider.providerUnavailableMessage,
            reviewFallback: provider.reviewFallback,
            searchSessionId: response.searchSessionId
        )

        if let thumbURL = ImagePersistenceService.shared.persistThumbnail(for: session) {
            session.thumbnailImageURL = thumbURL
        }

        return session
    }

    static func decodeAnalyzeResponse(data: Data) throws -> AnalyzeSearchResponse {
        if let poll = try? JSONDecoder().decode(SearchSessionPollResponse.self, from: data),
           let nested = poll.response {
            nested.logIOSResultsDecoded(context: "session-poll")
            return nested
        }
        let decoded = try JSONDecoder().decode(AnalyzeSearchResponse.self, from: data)
        decoded.logIOSResultsDecoded(context: "decode-analyze-raw")
        return decoded
    }
}
