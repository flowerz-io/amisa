//
//  HomeViewModel.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI
import PhotosUI
import Combine

enum TextSearchError: LocalizedError {
    case emptyQuery

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return String(localized: "Saisis une requête.")
        }
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recentSessions: [SearchSession] = []
    @Published var presentPhotoPicker = false
    @Published var selectedItems: [PhotosPickerItem] = []
    @Published var textSearchError: String?

    private let searchHistoryService: SearchHistoryService
    private let imagePersistence: ImagePersistenceService
    private let apiClient: any APIClientProtocol

    init(
        searchHistoryService: SearchHistoryService,
        imagePersistence: ImagePersistenceService = .shared,
        apiClient: any APIClientProtocol = APIConfig.apiClient
    ) {
        self.searchHistoryService = searchHistoryService
        self.imagePersistence = imagePersistence
        self.apiClient = apiClient
        loadRecentSessions()
    }

    func loadRecentSessions() {
        recentSessions = searchHistoryService.recentSessions(limit: 5)
    }

    /// Recherche texte : page 1 Vinted (même endpoint que la pagination Results).
    func submitTextSearch(query: String) async throws -> SearchSession {
        textSearchError = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TextSearchError.emptyQuery }

        let response = try await apiClient.fetchVintedListingsPage(searchText: trimmed, page: 1)
        let listings = response.listings.map { MarketplaceListing.from($0) }

        let session = SearchSession(
            id: UUID(),
            imageFileName: nil,
            thumbnailImageURL: nil,
            searchQuery: trimmed,
            generatedQueries: [trimmed],
            attributes: nil,
            listings: listings,
            createdAt: Date(),
            vintedSearchFailed: false,
            mode: .textQuery
        )

        searchHistoryService.addSession(session)
        loadRecentSessions()
        return session
    }

    func onPhotoSelected(completion: @escaping (SharedImagePayload?) -> Void) {
        guard let item = selectedItems.first else {
            completion(nil)
            return
        }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               !data.isEmpty,
               let fileName = imagePersistence.saveImage(data) {
                let payload = SharedImagePayload(imageFileName: fileName)
                await MainActor.run {
                    completion(payload)
                }
            } else {
                await MainActor.run {
                    completion(nil)
                }
            }
        }
    }
}
