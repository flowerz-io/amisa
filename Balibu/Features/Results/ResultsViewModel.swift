//
//  ResultsViewModel.swift
//  Balibu
//
//  La session est déjà chargée au moment de la navigation.
//

import SwiftUI
import Combine

enum ResultsViewState: Equatable {
    case loaded(SearchSession)
    case empty
    case error(String)
}

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var state: ResultsViewState

    init(session: SearchSession) {
        if session.listings.isEmpty {
            self.state = .empty
        } else {
            self.state = .loaded(session)
        }
    }
}
