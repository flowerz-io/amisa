//
//  SharedSearchSessionStore.swift
//  Balibu
//

import Foundation

final class SharedSearchSessionStore {
    static let shared = SharedSearchSessionStore()

    static let appGroupIdentifier = ShareStorageService.appGroupIdentifier
    private static let sessionResultsDirectory = "SessionResults"
    private let storageKey = "balibu.pendingSharedSearchSession.v1"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    private init() {}

    /// Fichier JSON brut (réponse GET) dans le conteneur App Group.
    static func sessionResultJSONURL(fileName: String) -> URL? {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return nil
        }
        let dir = base.appendingPathComponent(sessionResultsDirectory, isDirectory: true)
        return dir.appendingPathComponent(fileName)
    }

    func save(_ session: PendingSharedSearchSession) throws {
        let data = try JSONEncoder().encode(session)
        userDefaults?.set(data, forKey: storageKey)
        userDefaults?.synchronize()
    }

    func updateStatus(_ status: String, searchQuery: String? = nil) {
        guard var s = peekPending() else { return }
        s.status = status
        if let q = searchQuery { s.searchQuery = q }
        try? save(s)
    }

    func updateCompletedResultJSONFileName(_ fileName: String?) {
        guard var s = peekPending() else { return }
        s.completedResultJSONFileName = fileName
        try? save(s)
    }

    func peekPending() -> PendingSharedSearchSession? {
        guard let data = userDefaults?.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(PendingSharedSearchSession.self, from: data)
    }

    func clear() {
        if let pending = peekPending() {
            removeSessionResultFileIfNeeded(pending.completedResultJSONFileName)
        }
        userDefaults?.removeObject(forKey: storageKey)
        userDefaults?.synchronize()
    }

    func removeSessionResultFileIfNeeded(_ fileName: String?) {
        guard let name = fileName, let url = Self.sessionResultJSONURL(fileName: name) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
