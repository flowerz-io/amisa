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

    private enum CodingKeys: String, CodingKey {
        case id, source, title, price, currency
        case imageUrl, thumbnailUrl, listingUrl
        case brand, size, condition
        case publishedAtRelative, relevanceScore, visualSimilarityScore
        case itemSize, sizeLabel, taille
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        source = try c.decode(String.self, forKey: .source)
        title = try c.decode(String.self, forKey: .title)
        price = try c.decode(Double.self, forKey: .price)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        thumbnailUrl = try c.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        listingUrl = try c.decodeIfPresent(String.self, forKey: .listingUrl)
        brand = try c.decodeIfPresent(String.self, forKey: .brand)
        size = Self.firstNonEmptyString(
            in: c,
            keys: [.size, .itemSize, .sizeLabel, .taille]
        )
        condition = try c.decodeIfPresent(String.self, forKey: .condition)
        publishedAtRelative = try c.decodeIfPresent(String.self, forKey: .publishedAtRelative)
        relevanceScore = try c.decodeIfPresent(Double.self, forKey: .relevanceScore)
        visualSimilarityScore = try c.decodeIfPresent(Double.self, forKey: .visualSimilarityScore)
    }

    private static func firstNonEmptyString(
        in container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            guard let raw = try? container.decodeIfPresent(String.self, forKey: key) else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

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

    /// Taille affichée normalisée en majuscules (champ API uniquement).
    var displaySize: String? {
        ListingSizeExtractor.normalizedSize(from: size)
    }

    /// Taille pour l’UI : champ API (jamais écrasé par `NS`) → fallback titre → `NS`.
    var resolvedSizeLabel: String {
        ListingSizeExtractor.resolvedLabel(size: size, title: title)
    }

    /// Libellé court pour la pill : `size` API ou `NS` si absent.
    var cardSizeLabel: String {
        if let normalized = ListingSizeExtractor.normalizedSize(from: size) {
            return normalized
        }
        if let raw = size?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }
        return ListingSizeExtractor.extractFromTitle(title) ?? "NS"
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
