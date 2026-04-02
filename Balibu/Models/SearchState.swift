//
//  SearchState.swift
//  Balibu
//
//  États de la recherche pour l'UI.
//

import Foundation

/// États de la recherche pour l'affichage.
enum SearchState: Equatable {
    case idle
    case loading
    case success(SearchSession)
    case error(String)
}
