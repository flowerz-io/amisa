//
//  ShareExtensionConstants.swift
//  BalibuShareExtension
//
//  Même base API que Balibu/Core/Networking/APIConfig (l’extension ne lie pas l’app).
//

import Foundation

enum ShareExtensionConstants {
    static let backendBaseURL = URL(string: "https://balibu-production.up.railway.app")!

    /// Aligné sur `Balibu/Core/Notifications/AmisaNotificationIdentifiers.swift`.
    enum Notifications {
        static let shareResultsReadyCategory = "amisa.category.shareResultsReady"
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
