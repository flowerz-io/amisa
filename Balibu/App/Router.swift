import SwiftUI
import Combine

@MainActor
final class Router: ObservableObject {
    @Published var path = NavigationPath()
    @Published var selectedTab: MainTab = .home

    func navigateToSharedImportReview(payload: SharedImportPayload) {
        selectedTab = .search
        path.append(AppRoute.sharedImportReview(payload: payload))
    }

    func navigateToShareImportProcessing(payload: SharedImportPayload) {
        selectedTab = .search
        path.append(AppRoute.shareImportProcessing(payload: payload))
    }

    func replaceShareImportWithResults(session: SearchSession) {
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(AppRoute.results(session: session))
    }

    func navigateToResults(session: SearchSession) {
        selectedTab = .search
        path.append(AppRoute.results(session: session))
    }

    func navigateToResultsFromFavorite(session: SearchSession) {
        selectedTab = .search
        path.append(AppRoute.results(session: session))
    }

    func navigateToSearchHistory() {
        selectedTab = .search
        path.append(AppRoute.searchHistory)
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func processPendingShareImportIfNeeded() {
        guard path.isEmpty else { return }
        guard let payload = ShareStorageService.shared.peekPendingShareImportPayload() else { return }
        navigateToShareImportProcessing(payload: payload)
    }

    func processPendingShareImportFromNotification() {
        guard let payload = ShareStorageService.shared.peekPendingShareImportPayload() else { return }
        selectedTab = .search
        path = NavigationPath()
        navigateToShareImportProcessing(payload: payload)
    }

    func handleIncomingURL(_ url: URL) {
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
            navigateToShareImportProcessing(payload: payload)
            return
        }

        if host == "shared" {
            if let payload = storage.consumeLegacyFilenamePayload() {
                navigateToSharedImportReview(payload: payload)
            }
        }
    }
}
