//
//  APIConfig.swift
//  Balibu
//
//  Configuration centralisée du backend.
//

import Foundation

enum APIConfig {
    /// Passe à `false` pour utiliser le backend réel.
    static var useMock: Bool { false }

    /// Client API à injecter. Point central pour basculer mock/live.
    static var apiClient: any APIClientProtocol {
        useMock ? MockAPIClient() : APIClient.shared
    }

    /// URL de base du backend.
    static var baseURL: URL {
        URL(string: "https://balibu-production.up.railway.app")!
    }
}
