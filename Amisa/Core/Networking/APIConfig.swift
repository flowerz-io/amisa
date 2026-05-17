//
//  APIConfig.swift
//

import Foundation

enum APIConfig {
    /// Passe à `true` pour utiliser le mock (tests / offline).
    static var useMock: Bool { false }

    /// Client API à injecter. Point central pour basculer mock/live.
    static var apiClient: any APIClientProtocol {
        useMock ? MockAPIClient() : APIClient.shared
    }

    /// URL de base du backend (sans slash final).
    static var baseURL: URL { AppConfig.backendBaseURL }
}
