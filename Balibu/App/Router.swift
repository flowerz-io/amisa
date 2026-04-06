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

    /// Après session Share Extension : vide le pending App Group puis affiche les résultats.
    func navigateToResultsFromSharedSession(session: SearchSession) {
        selectedTab = .search
        SharedSearchSessionStore.shared.clear()
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(AppRoute.results(session: session))
    }

    func navigateToRemoteSessionLoading(sessionId: String) {
        selectedTab = .search
        path.append(AppRoute.remoteSessionLoading(sessionId: sessionId))
    }

    func navigateToSessionResumeFailed(message: String) {
        selectedTab = .search
        SharedSearchSessionStore.shared.clear()
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(AppRoute.sharedSessionResumeFailed(message: message))
    }

    func dismissCurrentRoute() {
        if !path.isEmpty {
            path.removeLast()
        }
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
        if SharedSearchSessionStore.shared.peekPending() != nil { return }
        guard let payload = ShareStorageService.shared.peekPendingShareImportPayload() else { return }
        navigateToShareImportProcessing(payload: payload)
    }

    func processPendingShareImportFromNotification() {
        guard let payload = ShareStorageService.shared.peekPendingShareImportPayload() else { return }
        selectedTab = .search
        path = NavigationPath()
        navigateToShareImportProcessing(payload: payload)
    }

    /// Tap sur notification « résultats prêts » : préfère `sessionId` si fourni.
    func handleShareResultsNotificationResponse(userInfo: [AnyHashable: Any]) {
        if let sid = userInfo[BalibuNotificationIdentifiers.sessionIdUserInfoKey] as? String,
           !sid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            selectedTab = .search
            path = NavigationPath()
            Task {
                await SharedSearchLaunchCoordinator.openSessionFromNotification(
                    sessionId: sid,
                    router: self,
                    apiClient: APIConfig.apiClient
                )
            }
            return
        }
        processPendingShareImportFromNotification()
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
