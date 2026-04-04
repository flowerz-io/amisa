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
    /// `pending` tant que l’app n’a pas terminé l’analyse et marqué la consommation.
    private let shareImportStatusKey = "balibu.shareImportStatus"
    private let shareImportStatusPending = "pending"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    private init() {}

    private func payloadStorageKey(for id: UUID) -> String {
        "balibu.importPayload.\(id.uuidString)"
    }

    /// Enregistre un payload complet (JSON) + id + statut pending (aligné extension / app).
    func savePendingImport(_ payload: SharedImportPayload) throws {
        let data = try JSONEncoder().encode(payload)
        userDefaults?.set(data, forKey: payloadStorageKey(for: payload.id))
        userDefaults?.set(payload.id.uuidString, forKey: pendingImportIdKey)
        userDefaults?.set(shareImportStatusPending, forKey: shareImportStatusKey)
        userDefaults?.synchronize()
    }

    /// Lit et supprime le payload pour cet id (deep link manuel / rétrocompat). Ne supprime que si le JSON est valide.
    func consumePayload(id: UUID) -> SharedImportPayload? {
        let key = payloadStorageKey(for: id)
        guard let data = userDefaults?.data(forKey: key) else { return nil }
        guard let payload = try? JSONDecoder().decode(SharedImportPayload.self, from: data) else {
            return nil
        }
        removePayloadKeys(for: id)
        return payload
    }

    /// Import Share Extension en attente : lecture **sans** suppression (l’app lance l’analyse puis `markPendingShareImportConsumed`).
    func peekPendingShareImportPayload() -> SharedImportPayload? {
        guard let idString = userDefaults?.string(forKey: pendingImportIdKey),
              let id = UUID(uuidString: idString) else { return nil }
        let key = payloadStorageKey(for: id)
        guard let data = userDefaults?.data(forKey: key) else { return nil }
        guard let payload = try? JSONDecoder().decode(SharedImportPayload.self, from: data),
              payload.id == id else {
            return nil
        }
        let status = userDefaults?.string(forKey: shareImportStatusKey)
        if status == nil {
            // Ancienne écriture sans clé de statut : traiter comme en attente.
            return payload
        }
        guard status == shareImportStatusPending else { return nil }
        return payload
    }

    /// Après navigation vers Results (analyse réussie) : supprime JSON, id, statut (le fichier image est nettoyé par le VM).
    func markPendingShareImportConsumed(id: UUID) {
        removePayloadKeys(for: id)
    }

    private func removePayloadKeys(for id: UUID) {
        let key = payloadStorageKey(for: id)
        userDefaults?.removeObject(forKey: key)
        if userDefaults?.string(forKey: pendingImportIdKey) == id.uuidString {
            userDefaults?.removeObject(forKey: pendingImportIdKey)
        }
        userDefaults?.removeObject(forKey: shareImportStatusKey)
        userDefaults?.synchronize()
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
        return peekPendingShareImportPayload() != nil
    }

    /// Efface tout ce qui concerne un import (ex. abandon).
    func clearPayload() {
        userDefaults?.removeObject(forKey: legacyFilenameKey)
        if let idString = userDefaults?.string(forKey: pendingImportIdKey),
           let id = UUID(uuidString: idString) {
            userDefaults?.removeObject(forKey: payloadStorageKey(for: id))
        }
        userDefaults?.removeObject(forKey: pendingImportIdKey)
        userDefaults?.removeObject(forKey: shareImportStatusKey)
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
