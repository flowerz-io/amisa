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
    var listings: [MarketplaceListing]
    let createdAt: Date
    /// La recherche Vinted initiale n’a pas pu être chargée (vision OK).
    var vintedSearchFailed: Bool
    var paginationState: SearchPaginationStateDTO?
    var rankingContext: SearchRankingContextDTO?
    /// Disponibilité providers (eBay bloqué, etc.) — renvoyé par l’API.
    var providerAvailability: ProviderAvailabilityMapDTO?
    /// Compteurs totaux backend par provider.
    var providerCounts: ProviderCountsDTO?
    /// Temps backend (ms) pour la première vague de résultats.
    var initialResponseTimeMs: Int?
    let mode: SearchSessionMode
    /// Jusqu’à 3 URLs d’aperçu (recherches manuelles), figées au premier chargement des résultats.
    let previewImageURLs: [URL]
    /// Session ouverte depuis la Share Extension pendant que Railway agrège encore les résultats — pas de bootstrap Vinted local.
    var awaitsRailwayHydration: Bool
    /// Écran résultats ouvert pendant que `analyze-search` ou recherche texte se termine encore (skeletons jusqu’à hydration).
    var hydratingBackendResults: Bool
    /// Snapshot reçu avant la fin de tous les providers (bandeau discret possible en UI).
    var moreProvidersPending: Bool
    /// Détails côté API si aucune annonce (providers en échec, etc.).
    var searchDebugMessage: String?
    /// Identifiant `GET /search-sessions/:id` tant que les providers lents peuvent encore enrichir les résultats.
    var searchSessionId: String?

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
        paginationState: SearchPaginationStateDTO? = nil,
        rankingContext: SearchRankingContextDTO? = nil,
        providerAvailability: ProviderAvailabilityMapDTO? = nil,
        providerCounts: ProviderCountsDTO? = nil,
        initialResponseTimeMs: Int? = nil,
        mode: SearchSessionMode = .imageAnalysis,
        previewImageURLs: [URL] = [],
        awaitsRailwayHydration: Bool = false,
        hydratingBackendResults: Bool = false,
        moreProvidersPending: Bool = false,
        searchDebugMessage: String? = nil,
        searchSessionId: String? = nil
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
        self.paginationState = paginationState
        self.rankingContext = rankingContext
        self.providerAvailability = providerAvailability
        self.providerCounts = providerCounts
        self.initialResponseTimeMs = initialResponseTimeMs
        self.mode = mode
        self.previewImageURLs = previewImageURLs
        self.awaitsRailwayHydration = awaitsRailwayHydration
        self.hydratingBackendResults = hydratingBackendResults
        self.moreProvidersPending = moreProvidersPending
        self.searchDebugMessage = searchDebugMessage
        self.searchSessionId = searchSessionId
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
            mode: .imageAnalysis,
            previewImageURLs: []
        )
    }
}

extension SearchSession: Codable {
    enum CodingKeys: String, CodingKey {
        case id, imageFileName, thumbnailImageURL, searchQuery, generatedQueries, attributes, listings, createdAt,
             vintedSearchFailed, paginationState, rankingContext, providerAvailability, providerCounts,
             initialResponseTimeMs, mode, previewImageURLs, awaitsRailwayHydration, hydratingBackendResults,
             moreProvidersPending, searchDebugMessage, searchSessionId
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
        let paginationState = try c.decodeIfPresent(SearchPaginationStateDTO.self, forKey: .paginationState)
        let rankingContext = try c.decodeIfPresent(SearchRankingContextDTO.self, forKey: .rankingContext)
        let providerAvailability = try c.decodeIfPresent(ProviderAvailabilityMapDTO.self, forKey: .providerAvailability)
        let providerCounts = try c.decodeIfPresent(ProviderCountsDTO.self, forKey: .providerCounts)
        let initialResponseTimeMs = try c.decodeIfPresent(Int.self, forKey: .initialResponseTimeMs)
        let mode = try c.decodeIfPresent(SearchSessionMode.self, forKey: .mode) ?? .imageAnalysis
        let previewImageURLs = try c.decodeIfPresent([URL].self, forKey: .previewImageURLs) ?? []
        let awaitsRailwayHydration = try c.decodeIfPresent(Bool.self, forKey: .awaitsRailwayHydration) ?? false
        let hydratingBackendResults = try c.decodeIfPresent(Bool.self, forKey: .hydratingBackendResults) ?? false
        let moreProvidersPending = try c.decodeIfPresent(Bool.self, forKey: .moreProvidersPending) ?? false
        let searchDebugMessage = try c.decodeIfPresent(String.self, forKey: .searchDebugMessage)
        let searchSessionId = try c.decodeIfPresent(String.self, forKey: .searchSessionId)
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
            paginationState: paginationState,
            rankingContext: rankingContext,
            providerAvailability: providerAvailability,
            providerCounts: providerCounts,
            initialResponseTimeMs: initialResponseTimeMs,
            mode: mode,
            previewImageURLs: previewImageURLs,
            awaitsRailwayHydration: awaitsRailwayHydration,
            hydratingBackendResults: hydratingBackendResults,
            moreProvidersPending: moreProvidersPending,
            searchDebugMessage: searchDebugMessage,
            searchSessionId: searchSessionId
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
        try c.encodeIfPresent(paginationState, forKey: .paginationState)
        try c.encodeIfPresent(rankingContext, forKey: .rankingContext)
        try c.encodeIfPresent(providerAvailability, forKey: .providerAvailability)
        try c.encodeIfPresent(providerCounts, forKey: .providerCounts)
        try c.encodeIfPresent(initialResponseTimeMs, forKey: .initialResponseTimeMs)
        try c.encode(mode, forKey: .mode)
        try c.encode(previewImageURLs, forKey: .previewImageURLs)
        try c.encode(awaitsRailwayHydration, forKey: .awaitsRailwayHydration)
        try c.encode(hydratingBackendResults, forKey: .hydratingBackendResults)
        try c.encode(moreProvidersPending, forKey: .moreProvidersPending)
        try c.encodeIfPresent(searchDebugMessage, forKey: .searchDebugMessage)
        try c.encodeIfPresent(searchSessionId, forKey: .searchSessionId)
    }
}
