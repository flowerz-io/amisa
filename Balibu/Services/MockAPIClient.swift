//
//  MockAPIClient.swift
//  Balibu
//
//  Client mock pour tester sans backend réel.
//

import Foundation
import UIKit

/// Implémentation mock de APIClientProtocol pour tests et développement.
struct MockAPIClient: APIClientProtocol {
    var delaySeconds: Double = 1.0

    func analyzeAndSearch(image: UIImage) async throws -> AnalyzeSearchResponse {
        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        return AnalyzeSearchResponse.mock
    }

    func analyzeAndSearch(imageData: Data) async throws -> AnalyzeSearchResponse {
        try await analyzeAndSearch(image: UIImage(data: imageData) ?? UIImage())
    }

    func fetchVintedListingsPage(searchText: String, page: Int) async throws -> VintedListingsResponse {
        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 500_000_000))
        guard page >= 2 else {
            return VintedListingsResponse(listings: [], page: page, hasMore: false)
        }
        let extra: [MarketplaceListingDTO] = [
            MarketplaceListingDTO(
                id: "mock-p\(page)-1",
                source: "Vinted",
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
                source: "Vinted",
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

// MARK: - Mock response

extension AnalyzeSearchResponse {
    static var mock: AnalyzeSearchResponse {
        AnalyzeSearchResponse(
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
                "black leather split toe boots"
            ],
            listings: MarketplaceListingDTO.mockListings
        )
    }
}

extension MarketplaceListingDTO {
    static var mockListings: [MarketplaceListingDTO] {
        [
            MarketplaceListingDTO(
                id: "gr-1",
                source: "Grailed",
                title: "Maison Margiela Tabi Ankle Boots",
                price: 390,
                currency: "EUR",
                imageUrl: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400",
                thumbnailUrl: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400",
                listingUrl: "https://grailed.com/listings/gr-1",
                brand: "Maison Margiela",
                size: "42",
                condition: "Very Good"
            ),
            MarketplaceListingDTO(
                id: "v-1",
                source: "Vinted",
                title: "Black Leather Split Toe Boots",
                price: 185,
                currency: "EUR",
                imageUrl: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400",
                thumbnailUrl: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400",
                listingUrl: "https://vinted.fr/items/example",
                brand: nil,
                size: "41",
                condition: "Good"
            ),
        ]
    }
}
