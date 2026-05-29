//
//  ShareExtensionConstants.swift
//
//  Base API — l’extension ne peut pas importer le module app : la chaîne littérale est
//  dupliquée volontairement et doit rester alignée avec `AppConfig.backendBaseURLString`.

import Foundation

enum ShareExtensionConstants {
    /// Dupliqué volontairement — doit rester identique à `AppConfig.backendBaseURLString` (sync par commentaire).
    static let backendBaseURLString = "https://amisa-production.up.railway.app"
    static var backendBaseURL: URL { URL(string: backendBaseURLString)! }
    static var analyzeSearchURL: URL { backendBaseURL.appendingPathComponent("analyze-search") }
    static var resolveSharedURLURL: URL { backendBaseURL.appendingPathComponent("resolve-shared-url") }
    static var healthURL: URL { backendBaseURL.appendingPathComponent("health") }

    enum Notifications {
        static let shareResultsReadyCategory = "amisa.category.shareResultsReady"
        static let typeUserInfoKey = "type"
        static let importIdUserInfoKey = "importId"
        static let sessionIdUserInfoKey = "sessionId"
        static func shareResultsRequestIdentifier(importId: UUID) -> String {
            "amisa.shareResults.\(importId.uuidString)"
        }
        static func shareResultsRequestIdentifier(sessionId: String) -> String {
            "amisa.shareResults.session.\(sessionId)"
        }
    }
}
