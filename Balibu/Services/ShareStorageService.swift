//
//  ShareStorageService.swift
//  Balibu
//
//  Gère le payload partagé via App Group entre extension et app principale.
//

import Foundation

final class ShareStorageService {
    static let shared = ShareStorageService()

    static let appGroupIdentifier = "group.flowerz.io.Balibu"
    private let payloadKey = "balibu.sharedImagePayload"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    private init() {}

    /// Enregistre le payload partagé (appelé par la Share Extension).
    func savePayload(_ payload: SharedImagePayload) {
        userDefaults?.set(payload.imageFileName, forKey: payloadKey)
        userDefaults?.synchronize()
    }

    /// Récupère et consomme le payload (appelé par l'app principale).
    /// Retourne nil si aucun payload en attente.
    func consumePayload() -> SharedImagePayload? {
        guard let fileName = userDefaults?.string(forKey: payloadKey) else {
            return nil
        }
        userDefaults?.removeObject(forKey: payloadKey)
        userDefaults?.synchronize()
        return SharedImagePayload(imageFileName: fileName)
    }

    /// Vérifie si un payload est en attente sans le consommer.
    func hasPendingPayload() -> Bool {
        userDefaults?.string(forKey: payloadKey) != nil
    }

    /// Efface le payload (utilisé après nettoyage).
    func clearPayload() {
        userDefaults?.removeObject(forKey: payloadKey)
        userDefaults?.synchronize()
    }
}
