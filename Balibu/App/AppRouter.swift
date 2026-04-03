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
        router.navigateToSharedImportReview(payload: payload)
    }

    private func checkPendingSharedPayload() {
        let storage = ShareStorageService.shared
        guard let payload = storage.consumePayload() else { return }
        router.navigateToSharedImportReview(payload: payload)
    }
}
