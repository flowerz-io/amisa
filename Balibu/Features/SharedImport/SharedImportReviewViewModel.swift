//
//  SharedImportReviewViewModel.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI
import Combine
import UIKit

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

    /// Nouvelle image choisie : permet de relancer une analyse proprement.
    func resetToIdle() {
        searchState = .idle
    }

    /// Image déjà préparée dans l’App Group (Share Extension) : même pipeline que le recadrage in-app.
    func startAnalysisFromPreparedFile(completion: @escaping (SearchSession) -> Void) {
        guard let url = payload.imageURL,
              let data = try? Data(contentsOf: url),
              let ui = UIImage(data: data) else {
            searchState = .error(String(localized: "Image introuvable dans le conteneur partagé."))
            return
        }
        startSearch(croppedImage: ui, completion: completion)
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

                ProviderRuntimeAvailabilityStore.shared.merge(from: response.providerAvailability)

                var session = SearchSession(
                    id: UUID(),
                    imageFileName: nil,
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
                    initialResponseTimeMs: response.initialResponseTimeMs
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
                    completion(finalSession)
                    searchState = .success(finalSession)
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    searchState = .error(apiError.localizedDescription)
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
