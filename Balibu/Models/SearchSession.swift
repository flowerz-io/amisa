//
//  SearchSession.swift
//  Balibu
//
//  Session de recherche sauvegardée dans l'historique.
//

import Foundation
import UIKit

/// Origine de la session : analyse d’image ou requête texte seule (même pagination Vinted ensuite).
enum SearchSessionMode: String, Codable, Hashable {
    case imageAnalysis
    case textQuery
}

/// Session de recherche complète pour l'historique local.
struct SearchSession: Identifiable, Equatable, Hashable {
    let id: UUID
    var imageFileName: String?
    var thumbnailImageURL: URL?
    let searchQuery: String
    let generatedQueries: [String]
    let attributes: FashionVisionResult?
    let listings: [MarketplaceListing]
    let createdAt: Date
    /// La recherche Vinted initiale n’a pas pu être chargée (vision OK).
    var vintedSearchFailed: Bool
    let mode: SearchSessionMode

    init(
        id: UUID = UUID(),
        imageFileName: String?,
        thumbnailImageURL: URL? = nil,
        searchQuery: String,
        generatedQueries: [String] = [],
        attributes: FashionVisionResult?,
        listings: [MarketplaceListing],
        createdAt: Date = Date(),
        vintedSearchFailed: Bool = false,
        mode: SearchSessionMode = .imageAnalysis
    ) {
        self.id = id
        self.imageFileName = imageFileName
        self.thumbnailImageURL = thumbnailImageURL
        self.searchQuery = searchQuery
        self.generatedQueries = generatedQueries.isEmpty ? (searchQuery.isEmpty ? [] : [searchQuery]) : generatedQueries
        self.attributes = attributes
        self.listings = listings
        self.createdAt = createdAt
        self.vintedSearchFailed = vintedSearchFailed
        self.mode = mode
    }

    /// Recherche lancée uniquement depuis du texte (pas d’image source).
    var isTextOnlySearch: Bool { mode == .textQuery }

    /// Requête affichée (alias).
    var displayQuery: String? { searchQuery }
    var formattedDate: String { createdAt.formatted(date: .abbreviated, time: .shortened) }

    /// Image source pour affichage.
    var imageURL: URL? {
        guard let fileName = imageFileName else { return nil }
        return ImagePersistenceService.shared.fullPath(for: fileName)
    }

    /// UIImage chargée depuis le fichier (pour affichage).
    var sourceImage: UIImage? {
        guard let url = imageURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Alias pour la vue Results.
    var generatedQuery: String? { searchQuery }

    /// Texte utilisé pour la pagination Vinted (requête principale).
    var vintedPaginationQuery: String {
        let q = generatedQueries.first ?? searchQuery
        return q.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Attributs en chaînes pour affichage.
    var extractedAttributes: [String] {
        guard let attr = attributes else { return [] }
        var parts: [String] = []
        if let c = attr.category, !c.isEmpty { parts.append(c) }
        if let b = attr.probableBrand, !b.isEmpty { parts.append(b) }
        if let col = attr.color, !col.isEmpty { parts.append(col) }
        if let m = attr.material, !m.isEmpty { parts.append(m) }
        parts.append(contentsOf: attr.styleKeywords ?? [])
        return parts
    }
}

// MARK: - Mock

extension SearchSession {
    static var mock: SearchSession {
        SearchSession(
            imageFileName: nil,
            thumbnailImageURL: nil,
            searchQuery: "Maison Margiela tabi boots black",
            attributes: FashionVisionResult(
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
            listings: MarketplaceListing.mockListings,
            createdAt: Date(),
            mode: .imageAnalysis
        )
    }
}

extension SearchSession: Codable {
    enum CodingKeys: String, CodingKey {
        case id, imageFileName, thumbnailImageURL, searchQuery, generatedQueries, attributes, listings, createdAt,
             vintedSearchFailed, mode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(UUID.self, forKey: .id)
        let imageFileName = try c.decodeIfPresent(String.self, forKey: .imageFileName)
        let thumbnailImageURL = try c.decodeIfPresent(URL.self, forKey: .thumbnailImageURL)
        let searchQuery = try c.decode(String.self, forKey: .searchQuery)
        let decodedQueries = try c.decodeIfPresent([String].self, forKey: .generatedQueries)
        let generatedQueries = decodedQueries ?? (searchQuery.isEmpty ? [] : [searchQuery])
        let attributes = try c.decodeIfPresent(FashionVisionResult.self, forKey: .attributes)
        let listings = try c.decode([MarketplaceListing].self, forKey: .listings)
        let createdAt = try c.decode(Date.self, forKey: .createdAt)
        let vintedSearchFailed = try c.decodeIfPresent(Bool.self, forKey: .vintedSearchFailed) ?? false
        let mode = try c.decodeIfPresent(SearchSessionMode.self, forKey: .mode) ?? .imageAnalysis
        self.init(
            id: id,
            imageFileName: imageFileName,
            thumbnailImageURL: thumbnailImageURL,
            searchQuery: searchQuery,
            generatedQueries: generatedQueries,
            attributes: attributes,
            listings: listings,
            createdAt: createdAt,
            vintedSearchFailed: vintedSearchFailed,
            mode: mode
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try c.encodeIfPresent(thumbnailImageURL, forKey: .thumbnailImageURL)
        try c.encode(searchQuery, forKey: .searchQuery)
        try c.encodeIfPresent(generatedQueries, forKey: .generatedQueries)
        try c.encodeIfPresent(attributes, forKey: .attributes)
        try c.encode(listings, forKey: .listings)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(vintedSearchFailed, forKey: .vintedSearchFailed)
        try c.encode(mode, forKey: .mode)
    }
}
