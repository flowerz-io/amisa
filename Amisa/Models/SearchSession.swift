//
//  SearchSession.swift
//  Balibu
//
//  Session de recherche sauvegardée dans l'historique.
//

import Foundation
import UIKit

enum SearchSessionMode: String, Codable, Hashable {
    case imageAnalysis
    case textQuery
}

private struct LegacyProviderPagination: Decodable {
    let nextPage: Int
    let hasMore: Bool
    let loadedCount: Int
}

private struct LegacySearchPaginationState: Decodable {
    let primaryQuery: String
    let vinted: LegacyProviderPagination
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
    var vintedSearchFailed: Bool
    var vintedPagination: VintedPaginationDTO?
    var initialResponseTimeMs: Int?
    let mode: SearchSessionMode
    let previewImageURLs: [URL]
    var awaitsRailwayHydration: Bool
    var hydratingBackendResults: Bool
    var searchDebugMessage: String?
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
        vintedPagination: VintedPaginationDTO? = nil,
        initialResponseTimeMs: Int? = nil,
        mode: SearchSessionMode = .imageAnalysis,
        previewImageURLs: [URL] = [],
        awaitsRailwayHydration: Bool = false,
        hydratingBackendResults: Bool = false,
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
        self.vintedPagination = vintedPagination
        self.initialResponseTimeMs = initialResponseTimeMs
        self.mode = mode
        self.previewImageURLs = previewImageURLs
        self.awaitsRailwayHydration = awaitsRailwayHydration
        self.hydratingBackendResults = hydratingBackendResults
        self.searchDebugMessage = searchDebugMessage
        self.searchSessionId = searchSessionId
    }

    var isTextOnlySearch: Bool { mode == .textQuery }

    var displayQuery: String? { searchQuery }
    var formattedDate: String { createdAt.formatted(date: .abbreviated, time: .shortened) }

    var imageURL: URL? {
        guard let fileName = imageFileName else { return nil }
        return ImagePersistenceService.shared.fullPath(for: fileName)
    }

    var sourceImage: UIImage? {
        guard let url = imageURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    var generatedQuery: String? { searchQuery }

    var vintedPaginationQuery: String {
        let q = generatedQueries.first ?? searchQuery
        return q.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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

extension SearchSession {
    static var mock: SearchSession {
        SearchSession(
            imageFileName: nil,
            thumbnailImageURL: nil,
            searchQuery: "bottines noires",
            attributes: FashionVisionResult(
                category: "footwear",
                subcategory: "ankle boots",
                dominantItem: "black leather ankle boots",
                probableBrand: nil,
                color: "black",
                material: "leather",
                styleKeywords: ["boots"],
                confidence: 0.84,
                sourceConfidence: 0.8,
                inferredEntity: nil,
                secondaryMarking: nil,
                inferredModel: nil,
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
        case id, imageFileName, thumbnailImageURL, searchQuery, generatedQueries, attributes, listings, createdAt
        case vintedSearchFailed, vintedPagination = "pagination"
        case legacyPaginationState = "paginationState"
        case initialResponseTimeMs, mode, previewImageURLs, awaitsRailwayHydration, hydratingBackendResults
        case searchDebugMessage, searchSessionId
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

        let vintedPagination: VintedPaginationDTO?
        if let v = try c.decodeIfPresent(VintedPaginationDTO.self, forKey: .vintedPagination) {
            vintedPagination = v
        } else if let leg = try c.decodeIfPresent(LegacySearchPaginationState.self, forKey: .legacyPaginationState) {
            vintedPagination = VintedPaginationDTO(
                primaryQuery: leg.primaryQuery,
                nextPage: leg.vinted.nextPage,
                hasMore: leg.vinted.hasMore,
                loadedCount: leg.vinted.loadedCount
            )
        } else {
            vintedPagination = nil
        }

        let initialResponseTimeMs = try c.decodeIfPresent(Int.self, forKey: .initialResponseTimeMs)
        let mode = try c.decodeIfPresent(SearchSessionMode.self, forKey: .mode) ?? .imageAnalysis
        let previewImageURLs = try c.decodeIfPresent([URL].self, forKey: .previewImageURLs) ?? []
        let awaitsRailwayHydration = try c.decodeIfPresent(Bool.self, forKey: .awaitsRailwayHydration) ?? false
        let hydratingBackendResults = try c.decodeIfPresent(Bool.self, forKey: .hydratingBackendResults) ?? false
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
            vintedPagination: vintedPagination,
            initialResponseTimeMs: initialResponseTimeMs,
            mode: mode,
            previewImageURLs: previewImageURLs,
            awaitsRailwayHydration: awaitsRailwayHydration,
            hydratingBackendResults: hydratingBackendResults,
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
        try c.encodeIfPresent(vintedPagination, forKey: .vintedPagination)
        try c.encodeIfPresent(initialResponseTimeMs, forKey: .initialResponseTimeMs)
        try c.encode(mode, forKey: .mode)
        try c.encode(previewImageURLs, forKey: .previewImageURLs)
        try c.encode(awaitsRailwayHydration, forKey: .awaitsRailwayHydration)
        try c.encode(hydratingBackendResults, forKey: .hydratingBackendResults)
        try c.encodeIfPresent(searchDebugMessage, forKey: .searchDebugMessage)
        try c.encodeIfPresent(searchSessionId, forKey: .searchSessionId)
    }
}
