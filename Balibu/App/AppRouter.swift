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
    let appDelegate: BalibuAppDelegate
    @Environment(\.scenePhase) private var scenePhase

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
            .onAppear {
                appDelegate.router = router
                Task { await NotificationManager.shared.refreshAuthorizationStatus() }
                router.processPendingShareImportIfNeeded()
                if router.path.isEmpty {
                    checkPendingLegacySharedPayload()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    router.processPendingShareImportIfNeeded()
                }
            }
        }
    }

    /// Ancien flux : fichier seul sans deep link id (clé legacy UserDefaults).
    private func checkPendingLegacySharedPayload() {
        let storage = ShareStorageService.shared
        guard let payload = storage.consumeLegacyFilenamePayload() else { return }
        router.navigateToSharedImportReview(payload: payload)
    }
}
