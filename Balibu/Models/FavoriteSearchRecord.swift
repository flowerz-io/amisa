//
//  FavoriteSearchRecord.swift
//  Balibu
//
//  Favori = recherche (métadonnées + références image), pas un snapshot des annonces.
//

import Foundation

struct FavoriteSearchRecord: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let createdAt: Date
    var imageFileName: String?
    var thumbnailImageURL: URL?
    let searchQuery: String
    let generatedQueries: [String]
    let attributes: FashionVisionResult?
    let vintedSearchFailed: Bool
    let mode: SearchSessionMode

    func toSearchSession() -> SearchSession {
        SearchSession(
            id: id,
            imageFileName: imageFileName,
            thumbnailImageURL: thumbnailImageURL,
            searchQuery: searchQuery,
            generatedQueries: generatedQueries,
            attributes: attributes,
            listings: [],
            createdAt: createdAt,
            vintedSearchFailed: vintedSearchFailed,
            mode: mode
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, imageFileName, thumbnailImageURL, searchQuery, generatedQueries, attributes,
             vintedSearchFailed, mode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        imageFileName = try c.decodeIfPresent(String.self, forKey: .imageFileName)
        thumbnailImageURL = try c.decodeIfPresent(URL.self, forKey: .thumbnailImageURL)
        searchQuery = try c.decode(String.self, forKey: .searchQuery)
        generatedQueries = try c.decodeIfPresent([String].self, forKey: .generatedQueries) ?? []
        attributes = try c.decodeIfPresent(FashionVisionResult.self, forKey: .attributes)
        vintedSearchFailed = try c.decodeIfPresent(Bool.self, forKey: .vintedSearchFailed) ?? false
        mode = try c.decodeIfPresent(SearchSessionMode.self, forKey: .mode) ?? .imageAnalysis
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try c.encodeIfPresent(thumbnailImageURL, forKey: .thumbnailImageURL)
        try c.encode(searchQuery, forKey: .searchQuery)
        try c.encode(generatedQueries, forKey: .generatedQueries)
        try c.encodeIfPresent(attributes, forKey: .attributes)
        try c.encode(vintedSearchFailed, forKey: .vintedSearchFailed)
        try c.encode(mode, forKey: .mode)
    }
}

extension SearchSession {
    var favoriteRecord: FavoriteSearchRecord {
        FavoriteSearchRecord(
            id: id,
            createdAt: createdAt,
            imageFileName: imageFileName,
            thumbnailImageURL: thumbnailImageURL,
            searchQuery: searchQuery,
            generatedQueries: generatedQueries,
            attributes: attributes,
            vintedSearchFailed: vintedSearchFailed,
            mode: mode
        )
    }
}

extension FavoriteSearchRecord {
    init(
        id: UUID,
        createdAt: Date,
        imageFileName: String?,
        thumbnailImageURL: URL?,
        searchQuery: String,
        generatedQueries: [String],
        attributes: FashionVisionResult?,
        vintedSearchFailed: Bool,
        mode: SearchSessionMode
    ) {
        self.id = id
        self.createdAt = createdAt
        self.imageFileName = imageFileName
        self.thumbnailImageURL = thumbnailImageURL
        self.searchQuery = searchQuery
        self.generatedQueries = generatedQueries
        self.attributes = attributes
        self.vintedSearchFailed = vintedSearchFailed
        self.mode = mode
    }
}
