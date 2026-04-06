//
//  ShareExtensionSearchAPI.swift
//  BalibuShareExtension
//
//  POST /search-sessions + GET /search-sessions/:id (sans dépendre des modules de l’app).
//

import Foundation

enum ShareExtensionSearchAPI {
    private static let session = URLSession.shared

    struct StartResponse: Decodable {
        let sessionId: String
        let status: String
        let searchQuery: String?
    }

    static func startSearchSession(imageData: Data) async throws -> StartResponse {
        let url = ShareExtensionConstants.backendBaseURL.appendingPathComponent("search-sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "imageBase64": imageData.base64EncodedString(),
            "enabledProviders": ShareExtensionProviderID.enabledBackendKeys(),
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ShareExtensionSearchAPIError.invalidResponse
        }
        guard http.statusCode == 202 else {
            throw ShareExtensionSearchAPIError.http(http.statusCode)
        }
        return try JSONDecoder().decode(StartResponse.self, from: data)
    }

    static func fetchSessionData(sessionId: String) async throws -> Data {
        let url = ShareExtensionConstants.backendBaseURL
            .appendingPathComponent("search-sessions")
            .appendingPathComponent(sessionId)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ShareExtensionSearchAPIError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw ShareExtensionSearchAPIError.http(http.statusCode)
        }
        return data
    }

    static func statusString(from jsonData: Data) throws -> String {
        let obj = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        guard let s = obj?["status"] as? String else {
            throw ShareExtensionSearchAPIError.badPayload
        }
        return s
    }
}

enum ShareExtensionSearchAPIError: LocalizedError {
    case invalidResponse
    case http(Int)
    case badPayload

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: "Réponse invalide du serveur")
        case .http(let code):
            return String(localized: "Erreur serveur (\(code))")
        case .badPayload:
            return String(localized: "Données inattendues")
        }
    }
}
