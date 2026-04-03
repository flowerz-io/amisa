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

    func navigateToSharedImportReview(payload: SharedImagePayload) {
        path.append(AppRoute.sharedImportReview(payload: payload))
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
