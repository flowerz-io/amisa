//
//  ShareExtensionConstants.swift
//  BalibuShareExtension
//
//  Même base API que Balibu/Core/Networking/APIConfig (l’extension ne lie pas l’app).
//

import Foundation

enum ShareExtensionConstants {
    static let backendBaseURL = URL(string: "https://balibu-production.up.railway.app")!

    /// Aligné sur `Balibu/Core/Notifications/BalibuNotificationIdentifiers.swift`.
    enum Notifications {
        static let shareResultsReadyCategory = "balibu.category.shareResultsReady"
        static let importIdUserInfoKey = "importId"
        static func shareResultsRequestIdentifier(importId: UUID) -> String {
            "balibu.shareResults.\(importId.uuidString)"
        }
    }
}
