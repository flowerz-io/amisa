//
//  AppRouter.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI
import Combine

enum AppRoute: Hashable {
    case home
    case imageCrop(payload: SharedImagePayload)
    case sharedImportReview(payload: SharedImagePayload)
    case results(session: SearchSession)
    case searchHistory
}

struct AppRouter: View {
    @ObservedObject var router: Router

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView(searchHistoryService: .shared)
                .environmentObject(router)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .home:
                    EmptyView()
                case .imageCrop(let payload):
                    ImageCropView(
                        payload: payload,
                        onConfirm: { croppedImage in
                            guard let data = croppedImage.jpegData(compressionQuality: 0.9),
                                  let fileName = ImagePersistenceService.shared.saveImage(data) else { return }
                            let newPayload = SharedImagePayload(imageFileName: fileName)
                            ImagePersistenceService.shared.cleanupTemporaryImage(at: payload.imageURL)
                            router.navigateToSharedImport(payload: newPayload)
                        },
                        onCancel: { router.popToRoot() }
                    )
                case .sharedImportReview(let payload):
                    SharedImportReviewView(payload: payload)
                case .results(let session):
                    ResultsView(session: session)
                case .searchHistory:
                    SearchHistoryView()
                }
            }
            .onOpenURL { url in
                handleOpenURL(url)
            }
            .onAppear {
                checkPendingSharedPayload()
            }
        }
    }
    
    private func handleOpenURL(_ url: URL) {
        guard url.scheme?.lowercased() == "balibu", url.host == "shared" else { return }
        let storage = ShareStorageService.shared
        guard let payload = storage.consumePayload() else { return }
        router.navigateToImageCrop(payload: payload)
    }

    private func checkPendingSharedPayload() {
        let storage = ShareStorageService.shared
        guard let payload = storage.consumePayload() else { return }
        router.navigateToImageCrop(payload: payload)
    }
}
