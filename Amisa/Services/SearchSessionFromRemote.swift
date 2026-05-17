//
//  SearchSessionFromRemote.swift
//  Balibu
//
//  Construit une SearchSession locale à partir d’une réponse API.
//

import Foundation
import UIKit

enum SearchSessionFromRemote {
    @MainActor
    static func buildSession(
        response: AnalyzeSearchResponse,
        imageFileName: String?
    ) -> SearchSession {
        let primaryQuery: String = {
            if let q = response.generatedQueries.first?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
                return q
            }
            if let ctx = response.rankingContext {
                let q = ctx.primaryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !q.isEmpty { return q }
            }
            return ""
        }()
        let listings = response.listings.map { MarketplaceListing.from($0) }

        ProviderRuntimeAvailabilityStore.shared.merge(from: response.providerAvailability)

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
            paginationState: response.pagination,
            rankingContext: response.rankingContext,
            providerAvailability: response.providerAvailability,
            providerCounts: response.providerCounts,
            initialResponseTimeMs: response.initialResponseTimeMs,
            moreProvidersPending: response.moreProvidersPending ?? false
        )

        if let thumbURL = ImagePersistenceService.shared.persistThumbnail(for: session) {
            session.thumbnailImageURL = thumbURL
        }

        return session
    }

    /// Décode un JSON (réponse GET complète ou objet `response` seul) vers `AnalyzeSearchResponse`.
    static func decodeAnalyzeResponse(data: Data) throws -> AnalyzeSearchResponse {
        if let poll = try? JSONDecoder().decode(SearchSessionPollResponse.self, from: data),
           let nested = poll.response {
            return nested
        }
        return try JSONDecoder().decode(AnalyzeSearchResponse.self, from: data)
    }
}
