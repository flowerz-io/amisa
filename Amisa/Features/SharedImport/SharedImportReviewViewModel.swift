//
//  SharedImportReviewViewModel.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI
import Combine
import UIKit

private enum SharedImportReviewError: LocalizedError {
    case imagePersistenceFailed

    var errorDescription: String? {
        switch self {
        case .imagePersistenceFailed:
            return String(localized: "Impossible d’enregistrer l’image.")
        }
    }
}

@MainActor
final class SharedImportReviewViewModel: ObservableObject {
    @Published var searchState: SearchState = .idle

    private let payload: SharedImportPayload
    private let apiClient: APIClientProtocol
    private var searchHistoryService: SearchHistoryService?
    private let shareStorage: ShareStorageService = .shared
    private let imagePersistence: ImagePersistenceService = .shared

    init(payload: SharedImportPayload, apiClient: any APIClientProtocol) {
        self.payload = payload
        self.apiClient = apiClient
    }

    func setSearchHistoryService(_ service: SearchHistoryService) {
        searchHistoryService = service
    }

    func setErrorMessage(_ message: String) {
        searchState = .error(message)
    }

    func resetToIdle() {
        searchState = .idle
    }

    /// Image déjà dans l’App Group (flux traitement automatique).
    var preparedUIImageForShareImport: UIImage? {
        guard let url = payload.imageURL,
              let data = try? Data(contentsOf: url),
              let ui = UIImage(data: data) else { return nil }
        return ui
    }

    /// JPEG prêt pour l’API + fichier persisté (une seule écriture).
    func preparePersistedImage(from croppedImage: UIImage) throws -> (data: Data, fileName: String) {
        let imageData = try ImageUploadPreprocessor.prepareForUpload(croppedImage)
        guard let fileName = imagePersistence.saveImage(imageData) else {
            throw SharedImportReviewError.imagePersistenceFailed
        }
        return (imageData, fileName)
    }

    /// Session minimale pour ouvrir Results tout de suite (skeletons).
    func hydratingPlaceholderSession(presetId: UUID, savedFileName: String) -> SearchSession {
        SearchSession(
            id: presetId,
            imageFileName: savedFileName,
            thumbnailImageURL: nil,
            searchQuery: "",
            generatedQueries: [],
            attributes: nil,
            listings: [],
            createdAt: Date(),
            mode: .imageAnalysis,
            hydratingBackendResults: true
        )
    }

    /// Réponse `analyze-search` complète ; réutilise le fichier image déjà sauvé et `presetId`.
    func fetchCompletedImageSession(imageData: Data, presetId: UUID, savedFileName: String) async throws -> SearchSession {
        let response = try await apiClient.analyzeAndSearch(imageData: imageData)

        let primaryQuery = response.generatedQueries.first ?? ""
        let listings = response.listings.map { MarketplaceListing.from($0) }

        ProviderRuntimeAvailabilityStore.shared.merge(from: response.providerAvailability)

        let session = SearchSession(
            id: presetId,
            imageFileName: savedFileName,
            thumbnailImageURL: nil,
            searchQuery: primaryQuery,
            generatedQueries: response.generatedQueries,
            attributes: response.visionResult,
            listings: listings,
            createdAt: Date(),
            vintedSearchFailed: response.vintedSearchFailed ?? false,
            paginationState: response.pagination,
            rankingContext: response.rankingContext,
            providerAvailability: response.providerAvailability,
            providerCounts: response.providerCounts,
            initialResponseTimeMs: response.initialResponseTimeMs,
            hydratingBackendResults: false
        )

        searchHistoryService?.addSession(session)

        var finalSession = session
        if let thumbURL = imagePersistence.persistThumbnail(for: session) {
            finalSession.thumbnailImageURL = thumbURL
        }

        imagePersistence.cleanupTemporaryImage(at: payload.imageURL)
        return finalSession
    }
}
