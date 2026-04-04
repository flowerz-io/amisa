//
//  ShareStorageService.swift
//  Balibu
//
//  Payload App Group : import par id (deep link) + compat ancienne clé fichier seul.
//

import Foundation

final class ShareStorageService {
    static let shared = ShareStorageService()

    static let appGroupIdentifier = "group.flowerz.io.Balibu"

    /// Ancienne clé : uniquement le nom de fichier (sans JSON).
    private let legacyFilenameKey = "balibu.sharedImagePayload"
    private let pendingImportIdKey = "balibu.pendingImportId"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    private init() {}

    private func payloadStorageKey(for id: UUID) -> String {
        "balibu.importPayload.\(id.uuidString)"
    }

    /// Enregistre un payload complet (JSON) + index optionnel pour diagnostic.
    func savePendingImport(_ payload: SharedImportPayload) throws {
        let data = try JSONEncoder().encode(payload)
        userDefaults?.set(data, forKey: payloadStorageKey(for: payload.id))
        userDefaults?.set(payload.id.uuidString, forKey: pendingImportIdKey)
        userDefaults?.synchronize()
    }

    /// Lit et supprime le payload pour cet id (après deep link).
    func consumePayload(id: UUID) -> SharedImportPayload? {
        let key = payloadStorageKey(for: id)
        guard let data = userDefaults?.data(forKey: key) else { return nil }
        userDefaults?.removeObject(forKey: key)
        if userDefaults?.string(forKey: pendingImportIdKey) == id.uuidString {
            userDefaults?.removeObject(forKey: pendingImportIdKey)
        }
        userDefaults?.synchronize()
        return try? JSONDecoder().decode(SharedImportPayload.self, from: data)
    }

    /// Ancien flux : une seule clé = nom de fichier (sans id). Consommé → Review classique.
    func consumeLegacyFilenamePayload() -> SharedImportPayload? {
        guard let fileName = userDefaults?.string(forKey: legacyFilenameKey) else {
            return nil
        }
        userDefaults?.removeObject(forKey: legacyFilenameKey)
        userDefaults?.synchronize()
        return SharedImportPayload(imageFileName: fileName)
    }

    func hasPendingPayload() -> Bool {
        if userDefaults?.string(forKey: legacyFilenameKey) != nil { return true }
        if let idString = userDefaults?.string(forKey: pendingImportIdKey),
           let id = UUID(uuidString: idString),
           userDefaults?.data(forKey: payloadStorageKey(for: id)) != nil {
            return true
        }
        return false
    }

    /// Efface tout ce qui concerne un import (ex. abandon).
    func clearPayload() {
        userDefaults?.removeObject(forKey: legacyFilenameKey)
        if let idString = userDefaults?.string(forKey: pendingImportIdKey),
           let id = UUID(uuidString: idString) {
            userDefaults?.removeObject(forKey: payloadStorageKey(for: id))
        }
        userDefaults?.removeObject(forKey: pendingImportIdKey)
        userDefaults?.synchronize()
    }

    // MARK: - Rétrocompat API nommée

    func savePayload(_ payload: SharedImportPayload) {
        try? savePendingImport(payload)
    }

    func consumePayload() -> SharedImportPayload? {
        consumeLegacyFilenamePayload()
    }
}
