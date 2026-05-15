//
//  SearchHistoryService.swift
//  Balibu
//
//  Historique local minimal des recherches.
//

import Foundation

extension Notification.Name {
    /// Publié après mise à jour du fichier d’historique (ex. refresh Discovery Home).
    static let amisaSearchHistoryDidUpdate = Notification.Name("amisa.searchHistory.didUpdate")
}

final class SearchHistoryService {
    static let shared = SearchHistoryService()
    private let maxItems = 50
    private let storageKey = "amisa.searchHistory"
    private let shareRailwayDedupePrefix = "amisa.shareRailwayHistoryCommitted."

    private var userDefaults: UserDefaults {
        UserDefaults.standard
    }

    private init() {}

    /// - Parameter shareRailwaySessionIdDedupe: Si non vide, n’ajoute qu’une fois par id Railway (réouvertures notification / resume).
    func addSession(_ session: SearchSession, shareRailwaySessionIdDedupe: String? = nil) {
        if let sid = shareRailwaySessionIdDedupe?.trimmingCharacters(in: .whitespacesAndNewlines), !sid.isEmpty {
            let flagKey = shareRailwayDedupePrefix + sid
            if userDefaults.bool(forKey: flagKey) {
                NotificationCenter.default.post(name: .amisaSearchHistoryDidUpdate, object: nil)
                return
            }
            userDefaults.set(true, forKey: flagKey)
        }

        var sessions = fetchSessions()
        sessions.insert(session, at: 0)
        if sessions.count > maxItems {
            sessions = Array(sessions.prefix(maxItems))
        }
        saveSessions(sessions)
        NotificationCenter.default.post(name: .amisaSearchHistoryDidUpdate, object: nil)
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
