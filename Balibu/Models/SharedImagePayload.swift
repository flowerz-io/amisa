//
//  SharedImagePayload.swift
//  Balibu
//
//  Payload partagé via App Group entre Share Extension et app principale.
//

import Foundation

/// Payload partagé par la Share Extension pour ouvrir l'app avec une image.
struct SharedImagePayload: Codable, Hashable {
    /// ID unique pour identifier cette session de partage.
    let id: UUID
    /// Nom du fichier image dans le conteneur App Group.
    let imageFileName: String
    /// Date de création du payload.
    let createdAt: Date

    init(id: UUID = UUID(), imageFileName: String, createdAt: Date = Date()) {
        self.id = id
        self.imageFileName = imageFileName
        self.createdAt = createdAt
    }

    /// URL complète du fichier image (SharedImages/ dans le conteneur App Group).
    var imageURL: URL? {
        ImagePersistenceService.shared.fullPath(for: imageFileName)
    }
}
