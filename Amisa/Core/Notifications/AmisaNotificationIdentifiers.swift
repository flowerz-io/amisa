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
    /// Type de notification (ex. `search_results_ready`).
    nonisolated static let typeUserInfoKey = "type"
    nonisolated static let searchResultsReadyType = "search_results_ready"
    nonisolated static func shareResultsRequestIdentifier(sessionId: String) -> String {
        "amisa.shareResults.session.\(sessionId)"
    }
    /// Préfixe + identifiant de requête (annulation après consommation).
    nonisolated static func shareResultsRequestIdentifier(importId: UUID) -> String {
        "amisa.shareResults.\(importId.uuidString)"
    }
}
