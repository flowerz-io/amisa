//
//  FavoriteSearchService.swift
//  Balibu
//
//  Persistance locale des favoris (UserDefaults + JSON).
//

import Foundation

final class FavoriteSearchService {
    static let shared = FavoriteSearchService()

    private let storageKey = "amisa.favoriteSearches"
    private let defaults = UserDefaults.standard

    private init() {}

    func allRecords() -> [FavoriteSearchRecord] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([FavoriteSearchRecord].self, from: data)) ?? []
    }

    func isFavorite(id: UUID) -> Bool {
        allRecords().contains(where: { $0.id == id })
    }

    @discardableResult
    func toggle(session: SearchSession) -> Bool {
        var list = allRecords()
        if let idx = list.firstIndex(where: { $0.id == session.id }) {
            list.remove(at: idx)
            save(list)
            return false
        }
        list.insert(session.favoriteRecord, at: 0)
        save(list)
        return true
    }

    func remove(id: UUID) {
        var list = allRecords()
        list.removeAll(where: { $0.id == id })
        save(list)
    }

    private func save(_ records: [FavoriteSearchRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
