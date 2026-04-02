//
//  SearchHistoryService.swift
//  Balibu
//
//  Historique local minimal des recherches.
//

import Foundation

final class SearchHistoryService {
    static let shared = SearchHistoryService()
    private let maxItems = 50
    private let storageKey = "balibu.searchHistory"

    private var userDefaults: UserDefaults {
        UserDefaults.standard
    }

    private init() {}

    func addSession(_ session: SearchSession) {
        var sessions = fetchSessions()
        sessions.insert(session, at: 0)
        if sessions.count > maxItems {
            sessions = Array(sessions.prefix(maxItems))
        }
        saveSessions(sessions)
    }

    func fetchSessions() -> [SearchSession] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([SearchSession].self, from: data)) ?? []
    }

    var sessions: [SearchSession] { fetchSessions() }

    func recentSessions(limit: Int = 5) -> [SearchSession] {
        Array(fetchSessions().prefix(limit))
    }

    func clearHistory() {
        userDefaults.removeObject(forKey: storageKey)
    }

    private func saveSessions(_ sessions: [SearchSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
