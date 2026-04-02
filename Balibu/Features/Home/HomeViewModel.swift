//
//  HomeViewModel.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI
import PhotosUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recentSessions: [SearchSession] = []
    @Published var presentPhotoPicker = false
    @Published var selectedItems: [PhotosPickerItem] = []

    private let searchHistoryService: SearchHistoryService
    private let imagePersistence: ImagePersistenceService

    init(
        searchHistoryService: SearchHistoryService,
        imagePersistence: ImagePersistenceService = .shared
    ) {
        self.searchHistoryService = searchHistoryService
        self.imagePersistence = imagePersistence
        loadRecentSessions()
    }

    func loadRecentSessions() {
        recentSessions = searchHistoryService.recentSessions(limit: 5)
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
