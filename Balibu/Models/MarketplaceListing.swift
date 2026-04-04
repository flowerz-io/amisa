//
//  MarketplaceListing.swift
//  Balibu
//
//  Annonce normalisée provenant d'une marketplace.
//

import Foundation

// MARK: - DTO (décodage JSON)

/// Listing brut décodé depuis la réponse API.
struct MarketplaceListingDTO: Decodable {
    let id: String
    let source: String
    let title: String
    let price: Double
    let currency: String?
    let imageUrl: String?
    let thumbnailUrl: String?
    let listingUrl: String?
    let brand: String?
    let size: String?
    let condition: String?
}

// MARK: - Modèle domaine

/// Annonce normalisée, source-agnostic.
struct MarketplaceListing: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let price: Double
    let currency: String?
    let imageURL: URL?
    let thumbnailURL: URL?
    let listingURL: URL?
    let source: String
    let brand: String?
    let size: String?
    let condition: String?

    /// Libellé badge (Vinted, Grailed, …) ; jamais vide côté UI.
    var sourceDisplayLabel: String {
        MarketplaceSource.displayLabel(from: source)
    }

    var formattedPrice: String {
        PriceFormatting.formatListingPrice(
            amount: price,
            currencyCode: currency,
            fallbackCurrencyCode: MarketplaceSource.defaultCurrencyCode(forSource: source)
        )
    }
}

// MARK: - Conversion DTO → Modèle

extension MarketplaceListing {
    static func from(_ dto: MarketplaceListingDTO) -> MarketplaceListing {
        MarketplaceListing(
            id: dto.id,
            title: dto.title,
            price: dto.price,
            currency: dto.currency,
            imageURL: dto.imageUrl.flatMap { URL(string: $0) },
            thumbnailURL: (dto.thumbnailUrl ?? dto.imageUrl).flatMap { URL(string: $0) },
            listingURL: dto.listingUrl.flatMap { URL(string: $0) },
            source: dto.source,
            brand: dto.brand,
            size: dto.size,
            condition: dto.condition
        )
    }
}

// MARK: - Mock

extension MarketplaceListing {
    static let mockListings: [MarketplaceListing] = [
        MarketplaceListing(
            id: "gr-1",
            title: "Maison Margiela Tabi Ankle Boots",
            price: 390,
            currency: "USD",
            imageURL: URL(string: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400"),
            thumbnailURL: URL(string: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=120"),
            listingURL: URL(string: "https://grailed.com/listings/gr-1"),
            source: "Grailed",
            brand: "Maison Margiela",
            size: "42",
            condition: "Very Good"
        ),
        MarketplaceListing(
            id: "gr-2",
            title: "Black Leather Split Toe Boots",
            price: 185,
            currency: "EUR",
            imageURL: URL(string: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400"),
            thumbnailURL: URL(string: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=120"),
            listingURL: URL(string: "https://vinted.fr/items/example"),
            source: "Vinted",
            brand: nil,
            size: "41",
            condition: "Good"
        ),
    ]
}
