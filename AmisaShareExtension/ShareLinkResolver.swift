//
//  ShareLinkResolver.swift
//  BalibuShareExtension
//
//  Abstraction pour résoudre une page web en images candidates. MVP : backend /resolve-shared-url.
//

import Foundation
import UIKit

/// Contrat pour brancher un backend ou un scraper local.
protocol ShareLinkResolving {
    /// Charge une ou plusieurs images candidates à partir d’une URL de page.
    func loadCandidateImages(from pageURL: URL) async throws -> [UIImage]
}

/// Appelle le backend Balibu (même contrat que POST /resolve-shared-url).
struct BackendShareLinkResolver: ShareLinkResolving {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = ShareExtensionConstants.backendBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func loadCandidateImages(from pageURL: URL) async throws -> [UIImage] {
        let url = baseURL.appendingPathComponent("resolve-shared-url")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["url": pageURL.absoluteString]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ShareLinkResolverError.invalidResponse
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ShareLinkResolverError.invalidResponse
        }
        if http.statusCode != 200 {
            let msg = obj["message"] as? String ?? "Erreur réseau"
            throw ShareLinkResolverError.serverError(http.statusCode, msg)
        }
        guard let b64 = obj["imageBase64"] as? String,
              let imgData = Data(base64Encoded: b64),
              let image = UIImage(data: imgData) else {
            throw ShareLinkResolverError.noImage
        }
        return [image]
    }
}

/// Résolution : aperçu local (LP + HTML + image directe), puis backend `/resolve-shared-url` si besoin.
struct CompositeShareLinkResolver: ShareLinkResolving {
    private let backend = BackendShareLinkResolver()

    func loadCandidateImages(from pageURL: URL) async throws -> [UIImage] {
        if let local = await ShareURLPreviewResolver.resolvePreview(for: pageURL) {
            return [local]
        }
        return try await backend.loadCandidateImages(from: pageURL)
    }
}

enum ShareLinkResolverError: LocalizedError {
    case invalidResponse
    case noImage
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Réponse invalide du serveur."
        case .noImage:
            return "Aucune image exploitable pour ce lien."
        case .serverError(_, let message):
            return message
        }
    }
}
