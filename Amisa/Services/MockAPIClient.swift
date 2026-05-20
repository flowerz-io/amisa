//
//  MockAPIClient.swift
//  Balibu
//

import Foundation
import UIKit

struct MockAPIClient: APIClientProtocol {
    var delaySeconds: Double = 1.0

    func analyzeAndSearch(image: UIImage) async throws -> AnalyzeSearchResponse {
        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        return AnalyzeSearchResponse.mock
    }

    func analyzeAndSearch(imageData: Data) async throws -> AnalyzeSearchResponse {
        try await analyzeAndSearch(image: UIImage(data: imageData) ?? UIImage())
    }

    func analyzeTextSearch(query: String) async throws -> AnalyzeSearchResponse {
        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 500_000_000))
        return AnalyzeSearchResponse.mock
    }

    func startSearchSession(imageData: Data) async throws -> StartSearchSessionResponse {
        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 300_000_000))
        return StartSearchSessionResponse(sessionId: "mock-session-\(UUID().uuidString.prefix(8))", status: "queued", searchQuery: nil)
    }

    func fetchSearchSessionStatus(sessionId: String) async throws -> SearchSessionPollResponse {
        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 400_000_000))
        return SearchSessionPollResponse(
            sessionId: sessionId,
            status: "completed",
            searchQuery: AnalyzeSearchResponse.mock.generatedQueries.first,
            error: nil,
            response: AnalyzeSearchResponse.mock,
            listings: AnalyzeSearchResponse.mock.listings
        )
    }

    func fetchVintedListingsPage(searchText: String, page: Int) async throws -> VintedListingsResponse {
        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 500_000_000))
        guard page >= 2 else {
            return VintedListingsResponse(listings: [], page: page, hasMore: false)
        }
        let extra: [MarketplaceListingDTO] = [
            MarketplaceListingDTO(
                id: "mock-p\(page)-1",
                source: "vinted",
                title: "Mock page \(page) — item A",
                price: 45,
                currency: "EUR",
                imageUrl: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400",
                thumbnailUrl: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=120",
                listingUrl: "https://www.vinted.fr/items/mock-p\(page)-1",
                brand: "Mock",
                size: "M",
                condition: "Bon état"
            ),
            MarketplaceListingDTO(
                id: "mock-p\(page)-2",
                source: "vinted",
                title: "Mock page \(page) — item B",
                price: 52,
                currency: "EUR",
                imageUrl: "https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=400",
                thumbnailUrl: "https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=120",
                listingUrl: "https://www.vinted.fr/items/mock-p\(page)-2",
                brand: nil,
                size: "L",
                condition: "Très bon état"
            ),
        ]
        return VintedListingsResponse(listings: extra, page: page, hasMore: page < 4)
    }
}

extension AnalyzeSearchResponse {
    static var mock: AnalyzeSearchResponse {
        AnalyzeSearchResponse(
            status: "completed",
            searchSessionId: nil,
            visionResult: FashionVisionResult(
                category: "footwear",
                subcategory: "ankle boots",
                dominantItem: "black leather ankle boots",
                probableBrand: "Maison Margiela",
                color: "black",
                material: "leather",
                styleKeywords: ["tabi", "split toe"],
                confidence: 0.84,
                sourceConfidence: 0.8,
                inferredEntity: nil,
                secondaryMarking: nil,
                inferredModel: "Tabi",
                dominantColorPrecise: "black",
                itemTypeCanonical: "boots"
            ),
            generatedQueries: [
                "Maison Margiela tabi boots black",
                "black leather split toe boots",
            ],
            listings: MarketplaceListingDTO.mockListings,
            pagination: VintedPaginationDTO(
                primaryQuery: "Maison Margiela tabi boots black",
                nextPage: 2,
                hasMore: true,
                loadedCount: 2
            ),
            vintedSearchFailed: nil,
            initialResponseTimeMs: 1200,
            searchDebugMessage: nil
        )
    }
}

extension MarketplaceListingDTO {
    static var mockListings: [MarketplaceListingDTO] {
        [
            MarketplaceListingDTO(
                id: "v-mock-1",
                source: "vinted",
                title: "Bottines cuir noir",
                price: 185,
                currency: "EUR",
                imageUrl: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400",
                thumbnailUrl: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400",
                listingUrl: "https://www.vinted.fr/items/v-mock-1",
                brand: nil,
                size: "41",
                condition: "Bon état"
            ),
            MarketplaceListingDTO(
                id: "v-mock-2",
                source: "vinted",
                title: "Boots Tabi style",
                price: 220,
                currency: "EUR",
                imageUrl: "https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=400",
                thumbnailUrl: "https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=400",
                listingUrl: "https://www.vinted.fr/items/v-mock-2",
                brand: "Créateur",
                size: "42",
                condition: "Très bon état"
            ),
        ]
    }
}
