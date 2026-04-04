//
//  BalibuNotificationIdentifiers.swift
//  Balibu
//
//  Identifiants alignés avec `ShareExtensionConstants.Notifications` (extension).
//

import Foundation

enum BalibuNotificationIdentifiers: Sendable {
    /// Catégorie pour filtrer les réponses dans le delegate.
    nonisolated static let shareResultsReadyCategory = "balibu.category.shareResultsReady"
    /// Clé userInfo pour l’UUID d’import (traçabilité).
    nonisolated static let importIdUserInfoKey = "importId"
    /// Préfixe + identifiant de requête (annulation après consommation).
    nonisolated static func shareResultsRequestIdentifier(importId: UUID) -> String {
        "balibu.shareResults.\(importId.uuidString)"
    }
}
