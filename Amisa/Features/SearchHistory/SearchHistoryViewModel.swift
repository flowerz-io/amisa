//
//  SearchHistoryViewModel.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI
import Combine

@MainActor
final class SearchHistoryViewModel: ObservableObject {
    @Published var sessions: [SearchSession] = []
    
    private let historyService: SearchHistoryService = .shared
    
    func load() {
        sessions = historyService.sessions
    }
}
