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
    case sharedImportReview(payload: SharedImportPayload)
    case shareImportProcessing(payload: SharedImportPayload)
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
                case .shareImportProcessing(let payload):
                    ShareImportProcessingView(payload: payload)
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
                checkPendingLegacySharedPayload()
            }
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard url.scheme?.lowercased() == "balibu" else { return }
        let host = (url.host ?? "").lowercased()
        let storage = ShareStorageService.shared

        if host == "shared-import" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
                  let id = UUID(uuidString: idString),
                  let payload = storage.consumePayload(id: id) else {
                return
            }
            router.navigateToShareImportProcessing(payload: payload)
            return
        }

        if host == "shared" {
            if let payload = storage.consumeLegacyFilenamePayload() {
                router.navigateToSharedImportReview(payload: payload)
            }
            return
        }
    }

    /// Ancien flux : fichier seul sans deep link id (clé legacy UserDefaults).
    private func checkPendingLegacySharedPayload() {
        let storage = ShareStorageService.shared
        guard let payload = storage.consumeLegacyFilenamePayload() else { return }
        router.navigateToSharedImportReview(payload: payload)
    }
}
