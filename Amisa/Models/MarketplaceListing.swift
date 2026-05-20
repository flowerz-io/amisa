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
    let publishedAtRelative: String?
    let relevanceScore: Double?
    /// Score similarité visuelle / couleur 0…100 (calcul client, optionnel).
    let visualSimilarityScore: Double?

    init(
        id: String,
        source: String,
        title: String,
        price: Double,
        currency: String?,
        imageUrl: String?,
        thumbnailUrl: String?,
        listingUrl: String?,
        brand: String?,
        size: String?,
        condition: String?,
        publishedAtRelative: String? = nil,
        relevanceScore: Double? = nil,
        visualSimilarityScore: Double? = nil
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.price = price
        self.currency = currency
        self.imageUrl = imageUrl
        self.thumbnailUrl = thumbnailUrl
        self.listingUrl = listingUrl
        self.brand = brand
        self.size = size
        self.condition = condition
        self.publishedAtRelative = publishedAtRelative
        self.relevanceScore = relevanceScore
        self.visualSimilarityScore = visualSimilarityScore
    }
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
    let publishedAtRelative: String?
    let relevanceScore: Double?
    /// Score similarité (re-classement couleur côté app, 0…100).
    var visualSimilarityScore: Double?

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

    /// Marque affichée : fallback "No brand" si absente/invalide.
    var displayBrand: String {
        let value = (brand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return "No brand" }
        let lowered = value.lowercased()
        if ["unknown", "undefined", "null"].contains(lowered) {
            return "No brand"
        }
        return value
    }

    /// Taille affichée normalisée en majuscules.
    var displaySize: String? {
        let value = (size ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return value.uppercased()
    }

    /// État affiché nettoyé.
    var displayCondition: String? {
        let value = (condition ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// URLs pour l’aperçu collage des recherches manuelles (ordre des annonces conservé).
    static func previewImageURLs(from listings: [MarketplaceListing], maxCount: Int = 3) -> [URL] {
        Array(listings.compactMap { $0.imageURL ?? $0.thumbnailURL }.prefix(maxCount))
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
            condition: dto.condition,
            publishedAtRelative: dto.publishedAtRelative,
            relevanceScore: dto.relevanceScore,
            visualSimilarityScore: dto.visualSimilarityScore
        )
    }
}

// MARK: - Mock

extension MarketplaceListing {
    static let mockListings: [MarketplaceListing] = [
        MarketplaceListing(
            id: "v-mock-1",
            title: "Bottines cuir noir",
            price: 45,
            currency: "EUR",
            imageURL: URL(string: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400"),
            thumbnailURL: URL(string: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=120"),
            listingURL: URL(string: "https://www.vinted.fr/items/v-mock-1"),
            source: "vinted",
            brand: "Vintage",
            size: "41",
            condition: "Très bon état",
            publishedAtRelative: nil,
            relevanceScore: 90,
            visualSimilarityScore: nil
        ),
        MarketplaceListing(
            id: "v-mock-2",
            title: "Boots style western",
            price: 32,
            currency: "EUR",
            imageURL: URL(string: "https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=400"),
            thumbnailURL: URL(string: "https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=120"),
            listingURL: URL(string: "https://www.vinted.fr/items/v-mock-2"),
            source: "vinted",
            brand: nil,
            size: "40",
            condition: "Bon état",
            publishedAtRelative: nil,
            relevanceScore: 72,
            visualSimilarityScore: nil
        ),
    ]
}
