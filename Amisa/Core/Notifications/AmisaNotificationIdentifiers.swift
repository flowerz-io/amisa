//
//  AmisaNotificationIdentifiers.swift
//  Balibu
//
//  Identifiants alignés avec `ShareExtensionConstants.Notifications` (extension).
//

import Foundation

enum AmisaNotificationIdentifiers: Sendable {
    /// Catégorie pour filtrer les réponses dans le delegate.
    nonisolated static let shareResultsReadyCategory = "amisa.category.shareResultsReady"
    /// Clé userInfo pour l’UUID d’import (traçabilité).
    nonisolated static let importIdUserInfoKey = "importId"
    /// Pivot de navigation vers une session Railway (prioritaire si présent).
    nonisolated static let sessionIdUserInfoKey = "sessionId"
    /// Préfixe + identifiant de requête (annulation après consommation).
    nonisolated static func shareResultsRequestIdentifier(importId: UUID) -> String {
        "amisa.shareResults.\(importId.uuidString)"
    }
}
