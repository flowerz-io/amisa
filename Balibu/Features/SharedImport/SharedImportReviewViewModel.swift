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

    func startSearch(completion: @escaping (SearchSession) -> Void) {
        guard let imageURL = payload.imageURL,
              let imageData = try? Data(contentsOf: imageURL) else {
            searchState = .error("Image not available")
            return
        }

        searchState = .loading

        Task {
            do {
                let response = try await apiClient.analyzeAndSearch(imageData: imageData)

                let primaryQuery = response.generatedQueries.first ?? ""
                let listings = response.listings.map { MarketplaceListing.from($0) }

                let session = SearchSession(
                    id: UUID(),
                    imageFileName: payload.imageFileName,
                    thumbnailImageURL: nil,
                    searchQuery: primaryQuery,
                    generatedQueries: response.generatedQueries,
                    attributes: response.visionResult,
                    listings: listings,
                    createdAt: Date()
                )

                searchHistoryService?.addSession(session)

                var finalSession = session
                if let thumbURL = imagePersistence.persistThumbnail(for: session) {
                    finalSession.thumbnailImageURL = thumbURL
                }

                await MainActor.run {
                    searchState = .success(finalSession)
                    completion(finalSession)
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
