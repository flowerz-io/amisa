//
//  PendingSharedSearchSession.swift
//  Balibu
//
//  État minimal partagé App Group (extension ↔ app). La vérité métier = Railway.
//

import Foundation

struct PendingSharedSearchSession: Codable, Equatable {
    let sessionId: String
    let createdAt: Date
    /// Ex: "share_extension"
    let source: String
    var status: String
    var previewImagePath: String?
    var originalImagePath: String?
    var searchQuery: String?
    /// Réponse GET complète (clé `response`) sauvegardée côté extension pour décodage dans l’app.
    var completedResultJSONFileName: String?
}
