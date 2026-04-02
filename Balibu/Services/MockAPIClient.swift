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
                sourceConfidence: 0.8
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
                size: "41",
                condition: "Good"
            ),
        ]
    }
}
