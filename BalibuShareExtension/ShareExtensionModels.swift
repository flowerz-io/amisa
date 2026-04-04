//
//  ShareExtensionModels.swift
//  BalibuShareExtension
//
//  Schéma Codable aligné sur Balibu/Models/SharedImportPayload.swift (ne pas diverger).
//

import Foundation

struct SharedImportPayload: Codable, Hashable {
    let id: UUID
    let imageFileName: String
    let createdAt: Date
    var sourceURL: String?

    init(id: UUID = UUID(), imageFileName: String, createdAt: Date = Date(), sourceURL: String? = nil) {
        self.id = id
        self.imageFileName = imageFileName
        self.createdAt = createdAt
        self.sourceURL = sourceURL
    }
}
