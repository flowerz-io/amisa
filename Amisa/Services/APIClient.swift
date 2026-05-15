//
//  APIClient.swift
//  Balibu
//
//  Client API pour l'endpoint POST /analyze-search.
//

import Foundation
import UIKit

// MARK: - Protocol (pour injection et mock)

protocol APIClientProtocol: Sendable {
    func analyzeAndSearch(image: UIImage) async throws -> AnalyzeSearchResponse
    func analyzeAndSearch(imageData: Data) async throws -> AnalyzeSearchResponse
    func analyzeTextSearch(query: String) async throws -> AnalyzeSearchResponse
    /// Session async (Share Extension) : lance le pipeline côté Railway, retourne `sessionId`.
    func startSearchSession(imageData: Data) async throws -> StartSearchSessionResponse
    /// État et résultat d’une session (source de vérité Railway).
    func fetchSearchSessionStatus(sessionId: String) async throws -> SearchSessionPollResponse
    /// Pages suivantes Vinted (page ≥ 2). La page 1 vient de `analyze-search`.
    func fetchVintedListingsPage(searchText: String, page: Int) async throws -> VintedListingsResponse
    /// Pagination multi-providers sans ré-analyse vision.
    func fetchSearchMore(request: SearchMoreRequest) async throws -> SearchMoreResponse
}

// MARK: - Implémentation réelle

actor APIClient: APIClientProtocol {
    func analyzeAndSearch(image: UIImage) async throws -> AnalyzeSearchResponse {
        let data = try ImageUploadPreprocessor.prepareForUpload(image)
        return try await analyzeAndSearch(imageData: data)
    }
    static let shared = APIClient()

    /// Fournit le client par défaut (pour injection).
    static func makeDefault() -> APIClient {
        shared
    }

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL? = nil) {
        self.baseURL = baseURL ?? APIConfig.baseURL
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
    }

    func analyzeAndSearch(imageData: Data) async throws -> AnalyzeSearchResponse {
        let url = baseURL.appending(path: "analyze-search")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let enabledProviders = ProviderSettingsStore.enabledProviderBackendKeysSnapshot()
        let body = AnalyzeSearchRequest(
            imageBase64: imageData.base64EncodedString(),
            enabledProviders: enabledProviders
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try decoder.decode(AnalyzeSearchResponse.self, from: data)
            } catch {
                throw APIError.invalidResponse
            }
        case 413:
            if let err = try? decoder.decode(APIErrorBody.self, from: data), err.error == "payload_too_large" {
                throw APIError.payloadTooLarge
            }
            throw APIError.payloadTooLarge
        case 422:
            if let err = try? decoder.decode(APIErrorBody.self, from: data) {
                switch err.error {
                case "low_confidence":
                    throw APIError.lowConfidence
                case "non_fashion":
                    throw APIError.nonFashion
                default:
                    break
                }
            }
            throw APIError.unknown(statusCode: 422)
        case 502:
            if let err = try? decoder.decode(APIErrorBody.self, from: data), err.error == "openai_error" {
                throw APIError.openAIError
            }
            throw APIError.unknown(statusCode: 502)
        case 400:
            throw APIError.badRequest
        case 500:
            throw APIError.serverError
        default:
            throw APIError.unknown(statusCode: httpResponse.statusCode)
        }
    }

    func startSearchSession(imageData: Data) async throws -> StartSearchSessionResponse {
        let url = baseURL.appending(path: "search-sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let enabledProviders = ProviderSettingsStore.enabledProviderBackendKeysSnapshot()
        let body = AnalyzeSearchRequest(
            imageBase64: imageData.base64EncodedString(),
            enabledProviders: enabledProviders
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 202:
            return try decoder.decode(StartSearchSessionResponse.self, from: data)
        case 413:
            throw APIError.payloadTooLarge
        case 400:
            throw APIError.badRequest
        case 500:
            throw APIError.serverError
        default:
            throw APIError.unknown(statusCode: httpResponse.statusCode)
        }
    }

    func fetchSearchSessionStatus(sessionId: String) async throws -> SearchSessionPollResponse {
        let url = baseURL.appending(path: "search-sessions").appending(path: sessionId)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200:
            return try decoder.decode(SearchSessionPollResponse.self, from: data)
        case 404:
            throw APIError.sessionNotFound
        default:
            throw APIError.unknown(statusCode: httpResponse.statusCode)
        }
    }

    func analyzeTextSearch(query: String) async throws -> AnalyzeSearchResponse {
        let url = baseURL.appending(path: "analyze-search")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let enabledProviders = ProviderSettingsStore.enabledProviderBackendKeysSnapshot()
        #if DEBUG
        print("[ANALYZE_TEXT_ENABLED_PROVIDERS]", enabledProviders)
        #endif
        let body = AnalyzeSearchRequest(
            textQuery: query,
            enabledProviders: enabledProviders
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try decoder.decode(AnalyzeSearchResponse.self, from: data)
        case 400:
            throw APIError.badRequest
        case 422:
            throw APIError.nonFashion
        case 500:
            throw APIError.serverError
        default:
            throw APIError.unknown(statusCode: httpResponse.statusCode)
        }
    }

    func fetchVintedListingsPage(searchText: String, page: Int) async throws -> VintedListingsResponse {
        let url = baseURL.appending(path: "vinted-listings")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = VintedListingsRequest(searchText: searchText, page: page)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try decoder.decode(VintedListingsResponse.self, from: data)
        case 400, 502:
            throw APIError.vintedSearchFailed
        default:
            throw APIError.unknown(statusCode: httpResponse.statusCode)
        }
    }

    func fetchSearchMore(request body: SearchMoreRequest) async throws -> SearchMoreResponse {
        let url = baseURL.appending(path: "search-more")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        #if DEBUG
        print("[SEARCH_MORE_ENABLED_PROVIDERS]", body.enabledProviders)
        #endif
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try decoder.decode(SearchMoreResponse.self, from: data)
        case 400, 502:
            throw APIError.searchMoreFailed
        default:
            throw APIError.unknown(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Error Response

private struct APIErrorBody: Decodable {
    let error: String?
    let message: String?
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidImage
    case invalidResponse
    case badRequest
    case serverError
    case sessionNotFound
    case lowConfidence
    case nonFashion
    case payloadTooLarge
    case openAIError
    case vintedSearchFailed
    case searchMoreFailed
    case unknown(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Image non exploitable"
        case .invalidResponse:
            return "Réponse invalide du serveur"
        case .sessionNotFound:
            return "Cette session de recherche n’existe plus ou a expiré."
        case .badRequest:
            return "Requête invalide. Vérifie l’image et réessaie."
        case .serverError:
            return "Serveur indisponible. Réessaie dans un instant."
        case .lowConfidence:
            return "Image trop ambiguë. Essaie avec un recadrage plus précis ou une photo plus nette."
        case .nonFashion:
            return "Cette image ne semble pas montrer un vêtement ou accessoire mode. Essaie une photo plus nette de l’article."
        case .payloadTooLarge:
            return "L’image est encore trop lourde après compression. Essaie une photo plus petite ou un recadrage plus serré."
        case .openAIError:
            return "L’analyse automatique n’a pas pu aboutir. Réessaie dans quelques instants."
        case .vintedSearchFailed:
            return "Impossible de charger les annonces Vinted pour le moment."
        case .searchMoreFailed:
            return "Impossible de charger davantage d’annonces pour le moment."
        case .unknown(let code):
            return "Erreur (\(code))"
        }
    }
}
