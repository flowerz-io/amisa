import SwiftUI
import Combine

@MainActor
final class Router: ObservableObject {
    @Published var path = NavigationPath()
    @Published var selectedTab: MainTab = .home

    /// Onglet d'origine avant de naviguer vers le tab .search.
    /// Restauré automatiquement quand path revient à vide.
    @Published var sourceTab: MainTab? = nil

    /// Contrôle l'ouverture de la caméra depuis MainTabContainerView.
    /// Utilisé par goBackToCamera() pour revenir à la caméra depuis Review.
    @Published var showCameraCapture = false

    /// Masque la tab bar flottante (Review, modes plein écran).
    /// Supprime aussi le padding bas du contenu pour que la vue remplisse l'écran.
    @Published var isTabBarHidden = false

    // MARK: - Source tab helpers

    private func saveSourceTabIfNeeded() {
        if selectedTab != .search {
            sourceTab = selectedTab
        }
    }

    func restoreSourceTabIfNeeded() {
        guard path.isEmpty, let source = sourceTab else { return }
        selectedTab = source
        sourceTab = nil
    }

    // MARK: - Navigation

    func navigateToSharedImportReview(payload: SharedImportPayload) {
        saveSourceTabIfNeeded()
        selectedTab = .search
        path.append(AppRoute.sharedImportReview(payload: payload))
    }

    func navigateToShareImportProcessing(payload: SharedImportPayload) {
        saveSourceTabIfNeeded()
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
        saveSourceTabIfNeeded()
        selectedTab = .search
        path.append(AppRoute.results(session: session))
    }

    func navigateToResultsFromFavorite(session: SearchSession) {
        saveSourceTabIfNeeded()
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
        saveSourceTabIfNeeded()
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

    /// Depuis Review : dépile la route courante et rouvre la caméra.
    func goBackToCamera() {
        if !path.isEmpty { path.removeLast() }
        showCameraCapture = true
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
