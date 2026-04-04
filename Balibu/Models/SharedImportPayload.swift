//
//  SharedImportPayload.swift
//  Balibu
//
//  Payload App Group entre Share Extension et app (même schéma Codable que l’extension).
//

import Foundation

/// Import partagé : image enregistrée dans SharedImages/ du conteneur App Group.
struct SharedImportPayload: Codable, Hashable {
    let id: UUID
    let imageFileName: String
    let createdAt: Date
    /// URL de page d’origine si import depuis un lien (optionnel).
    var sourceURL: String?

    init(id: UUID = UUID(), imageFileName: String, createdAt: Date = Date(), sourceURL: String? = nil) {
        self.id = id
        self.imageFileName = imageFileName
        self.createdAt = createdAt
        self.sourceURL = sourceURL
    }
}

/// Alias historique (Home, Review, routes).
typealias SharedImagePayload = SharedImportPayload

extension SharedImportPayload {
    /// Chemin fichier image dans l’App Group (via ImagePersistenceService).
    var imageURL: URL? {
        ImagePersistenceService.shared.fullPath(for: imageFileName)
    }
}
