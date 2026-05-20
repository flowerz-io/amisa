//
//  ShareContinuitySnapshot.swift
//  Balibu
//
//  Snapshot JSON écrit par la Share Extension (App Group) et relu au démarrage / notification.
//

import Foundation

/// Aligné sur `BalibuShareExtension/ShareContinuitySnapshot.swift` (schéma identique).
struct ShareContinuitySnapshotFile: Codable, Equatable {
    let schemaVersion: Int
    let sessionId: String
    let savedAt: Date
    let status: String
    let searchQuery: String?
    let listings: [ShareContinuityListingRow]
}

struct ShareContinuityListingRow: Codable, Equatable {
    let id: String
    let title: String
    let price: Double
    let currency: String?
    let imageURL: URL?
    let thumbnailURL: URL?
    let source: String
}

extension ShareContinuityListingRow {
    func toMarketplaceListing() -> MarketplaceListing {
        MarketplaceListing(
            id: id,
            title: title,
            price: price,
            currency: currency,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL ?? imageURL,
            listingURL: nil,
            source: source,
            brand: nil,
            size: nil,
            condition: nil,
            publishedAtRelative: nil,
            relevanceScore: nil,
            visualSimilarityScore: nil
        )
    }
}
