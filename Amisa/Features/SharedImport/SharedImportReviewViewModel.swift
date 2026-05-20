//
//  SharedImportReviewViewModel.swift
//  Balibu
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

    var preparedUIImageForShareImport: UIImage? {
        guard let url = payload.imageURL,
              let data = try? Data(contentsOf: url),
              let ui = UIImage(data: data) else { return nil }
        return ui
    }

    func preparePersistedImage(from croppedImage: UIImage) throws -> (data: Data, fileName: String) {
        let imageData = try ImageUploadPreprocessor.prepareForUpload(croppedImage)
        guard let fileName = imagePersistence.saveImage(imageData) else {
            throw SharedImportReviewError.imagePersistenceFailed
        }
        return (imageData, fileName)
    }

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

    func fetchCompletedImageSession(imageData: Data, presetId: UUID, savedFileName: String) async throws -> SearchSession {
        let response = try await apiClient.analyzeAndSearch(imageData: imageData)

        let primaryQuery = response.generatedQueries.first ?? ""
        let listings = response.listings.map { MarketplaceListing.from($0) }

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
            vintedPagination: response.pagination,
            initialResponseTimeMs: response.initialResponseTimeMs,
            hydratingBackendResults: false,
            searchDebugMessage: response.searchDebugMessage,
            searchSessionId: response.searchSessionId
        )

        searchHistoryService?.addSession(session)

        var finalSession = session
        if let thumbURL = imagePersistence.persistThumbnail(for: session) {
            finalSession.thumbnailImageURL = thumbURL
        }

        return finalSession
    }
}
