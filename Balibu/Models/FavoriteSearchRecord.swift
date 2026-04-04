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
            vintedSearchFailed: vintedSearchFailed
        )
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
            vintedSearchFailed: vintedSearchFailed
        )
    }
}
