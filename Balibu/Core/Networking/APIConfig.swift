//
//  APIConfig.swift
//  Balibu
//
//  Configuration centralisée du backend.
//

import Foundation
import UIKit

enum APIConfig {
    /// Passe à `false` pour utiliser le backend réel.
    static var useMock: Bool { false }

    /// Client API à injecter. Point central pour basculer mock/live.
    static var apiClient: any APIClientProtocol {
        useMock ? MockAPIClient() : APIClient.shared
    }

    /// URL de base du backend.
    static var baseURL: URL {
        URL(string: "http://127.0.0.1:3000")!
    }
}
