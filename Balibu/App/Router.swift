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

    func navigateToSharedImportReview(payload: SharedImportPayload) {
        path.append(AppRoute.sharedImportReview(payload: payload))
    }

    /// Import Share Extension terminé : analyse puis résultats (remplace l’écran de traitement).
    func navigateToShareImportProcessing(payload: SharedImportPayload) {
        path.append(AppRoute.shareImportProcessing(payload: payload))
    }

    func replaceShareImportWithResults(session: SearchSession) {
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(AppRoute.results(session: session))
    }

    func navigateToResults(session: SearchSession) {
        path.append(AppRoute.results(session: session))
    }

    func navigateToSearchHistory() {
        path.append(AppRoute.searchHistory)
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
