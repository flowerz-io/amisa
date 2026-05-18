//
//  APIConfig.swift
//

import Foundation

enum APIConfig {
    /// Passe à `true` pour utiliser le mock (tests / offline).
    static var useMock: Bool { false }

    /// Plafond attendu aligné sur `MAX_RESULTS_PER_SEARCH` (Railway, défaut 100). L’app ne tronque pas les listings renvoyés par `/analyze-search` ; clé Info.plist `MAX_RESULTS_PER_SEARCH` possible pour tests UI.
    static var maxResultsPerSearch: Int {
        if let s = Bundle.main.object(forInfoDictionaryKey: "MAX_RESULTS_PER_SEARCH") as? String,
           let v = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)), v > 0 {
            return v
        }
        if let v = Bundle.main.object(forInfoDictionaryKey: "MAX_RESULTS_PER_SEARCH") as? Int, v > 0 {
            return v
        }
        return 100
    }

    /// Client API à injecter. Point central pour basculer mock/live.
    static var apiClient: any APIClientProtocol {
        useMock ? MockAPIClient() : APIClient.shared
    }

    /// URL de base du backend (sans slash final).
    static var baseURL: URL { AppConfig.backendBaseURL }
}
