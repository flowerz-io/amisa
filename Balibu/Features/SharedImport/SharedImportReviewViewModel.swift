//
//  SharedImportReviewViewModel.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI
import Combine

@MainActor
final class SharedImportReviewViewModel: ObservableObject {
    @Published var searchState: SearchState = .idle

    private let payload: SharedImagePayload
    private let apiClient: APIClientProtocol
    private var searchHistoryService: SearchHistoryService?
    private let shareStorage: ShareStorageService = .shared
    private let imagePersistence: ImagePersistenceService = .shared

    init(payload: SharedImagePayload, apiClient: any APIClientProtocol) {
        self.payload = payload
        self.apiClient = apiClient
    }

    func setSearchHistoryService(_ service: SearchHistoryService) {
        searchHistoryService = service
    }

    func setErrorMessage(_ message: String) {
        searchState = .error(message)
    }

    /// Nouvelle image choisie : permet de relancer une analyse proprement.
    func resetToIdle() {
        searchState = .idle
    }

    /// Recadrage déjà appliqué côté UI ; préparation JPEG puis analyse.
    func startSearch(croppedImage: UIImage, completion: @escaping (SearchSession) -> Void) {
        searchState = .loading

        Task {
            let imageData: Data
            do {
                imageData = try ImageUploadPreprocessor.prepareForUpload(croppedImage)
            } catch {
                await MainActor.run {
                    searchState = .error(error.localizedDescription)
                }
                return
            }

            do {
                let response = try await apiClient.analyzeAndSearch(imageData: imageData)

                let primaryQuery = response.generatedQueries.first ?? ""
                let listings = response.listings.map { MarketplaceListing.from($0) }

                var session = SearchSession(
                    id: UUID(),
                    imageFileName: nil,
                    thumbnailImageURL: nil,
                    searchQuery: primaryQuery,
                    generatedQueries: response.generatedQueries,
                    attributes: response.visionResult,
                    listings: listings,
                    createdAt: Date(),
                    vintedSearchFailed: response.vintedSearchFailed ?? false
                )

                if let fileName = imagePersistence.saveImage(imageData) {
                    session.imageFileName = fileName
                }

                searchHistoryService?.addSession(session)

                var finalSession = session
                if let thumbURL = imagePersistence.persistThumbnail(for: session) {
                    finalSession.thumbnailImageURL = thumbURL
                }

                imagePersistence.cleanupTemporaryImage(at: payload.imageURL)

                await MainActor.run {
                    searchState = .success(finalSession)
                    completion(finalSession)
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    searchState = .error(apiError.localizedDescription ?? "Erreur")
                }
            } catch {
                await MainActor.run {
                    searchState = .error(error.localizedDescription)
                }
            }
        }
    }

    func cleanupAndDismiss(completion: @escaping () -> Void) {
        shareStorage.clearPayload()
        imagePersistence.cleanupTemporaryImage(at: payload.imageURL)
        completion()
    }
}
