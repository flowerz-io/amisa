//
//  Router.swift
//  Balibu
//
//  Coordonnateur de navigation pour l'app.
//

import SwiftUI
import Combine

@MainActor
final class Router: ObservableObject {
    @Published var path = NavigationPath()
    /// Onglet principal (0 = Rechercher) — les flows de résultats s’y empilent.
    @Published var selectedTab: Int = 0

    func navigateToSharedImportReview(payload: SharedImportPayload) {
        selectedTab = 0
        path.append(AppRoute.sharedImportReview(payload: payload))
    }

    /// Import Share Extension terminé : analyse puis résultats (remplace l’écran de traitement).
    func navigateToShareImportProcessing(payload: SharedImportPayload) {
        selectedTab = 0
        path.append(AppRoute.shareImportProcessing(payload: payload))
    }

    func replaceShareImportWithResults(session: SearchSession) {
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(AppRoute.results(session: session))
    }

    func navigateToResults(session: SearchSession) {
        selectedTab = 0
        path.append(AppRoute.results(session: session))
    }

    /// Ouvre les résultats depuis l’onglet Favoris (ou autre) en revenant sur l’onglet Rechercher.
    func navigateToResultsFromFavorite(session: SearchSession) {
        selectedTab = 0
        path.append(AppRoute.results(session: session))
    }

    func navigateToSearchHistory() {
        selectedTab = 0
        path.append(AppRoute.searchHistory)
    }

    func popToRoot() {
        path = NavigationPath()
    }

    /// Détecte un import Share Extension `pending` dans l’App Group et lance l’analyse (sans deep link).
    func processPendingShareImportIfNeeded() {
        guard path.isEmpty else { return }
        guard let payload = ShareStorageService.shared.peekPendingShareImportPayload() else { return }
        navigateToShareImportProcessing(payload: payload)
    }

    /// Tap sur la notification locale : réinitialise la pile puis lance le traitement du pending.
    func processPendingShareImportFromNotification() {
        guard let payload = ShareStorageService.shared.peekPendingShareImportPayload() else { return }
        selectedTab = 0
        path = NavigationPath()
        navigateToShareImportProcessing(payload: payload)
    }

    /// Deep links `balibu://` (optionnel ; l’import principal passe par `peekPendingShareImportPayload`).
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
