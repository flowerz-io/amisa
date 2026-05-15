//
//  ShareExtensionStorage.swift
//  BalibuShareExtension
//
//  Écriture App Group alignée sur ShareStorageService côté app.
//

import Foundation

enum ShareExtensionStorage {
    static let appGroupIdentifier = "group.flowerz.io.Amisa"
    private static let sharedImagesDirectory = "SharedImages"

    private static var sharedImagesURL: URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }
        return container.appendingPathComponent(sharedImagesDirectory)
    }

    private static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private static func payloadKey(for id: UUID) -> String {
        "amisa.importPayload.\(id.uuidString)"
    }

    private static let pendingImportIdKey = "amisa.pendingImportId"
    /// Aligné sur `ShareStorageService` : l’app lit ce statut au lancement pour lancer l’analyse.
    private static let shareImportStatusKey = "amisa.shareImportStatus"
    private static let shareImportStatusPending = "pending"

    /// JPEG dans `SharedImages` uniquement (flux session Railway — sans clés d’import legacy).
    static func saveJPEGToSharedImagesOnly(_ imageData: Data) throws -> String {
        guard let dir = sharedImagesURL else {
            throw ShareExtensionStorageError.containerUnavailable
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).jpg"
        try imageData.write(to: dir.appendingPathComponent(fileName))
        return fileName
    }

    /// Corps JSON brut d’un GET `/search-sessions/:id` (pour décodage dans l’app).
    static func saveSessionResultJSON(_ data: Data, sessionId: String) throws -> String {
        let fileName = "session-\(sessionId).json"
        guard let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw ShareExtensionStorageError.containerUnavailable
        }
        let dir = base.appendingPathComponent("SessionResults", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName)
        try data.write(to: url)
        return fileName
    }

    private static let continuityDirectory = "ContinuitySnapshots"

    /// Snapshot léger (listings + statut) pour reprendre le même état visuel dans l’app.
    static func saveContinuitySnapshot(_ data: Data, sessionId: String) throws -> String {
        let fileName = "continuity-\(sessionId).json"
        guard let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw ShareExtensionStorageError.containerUnavailable
        }
        let dir = base.appendingPathComponent(continuityDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: dir.appendingPathComponent(fileName))
        return fileName
    }

    /// Enregistre le JPEG final + JSON + id + statut `pending` (l’app consomme au prochain lancement).
    static func saveImport(payload: SharedImportPayload, imageData: Data) throws {
        guard let dir = sharedImagesURL else {
            throw ShareExtensionStorageError.containerUnavailable
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(payload.imageFileName)
        try imageData.write(to: fileURL)

        let encoded = try JSONEncoder().encode(payload)
        userDefaults?.set(encoded, forKey: payloadKey(for: payload.id))
        userDefaults?.set(payload.id.uuidString, forKey: pendingImportIdKey)
        userDefaults?.set(shareImportStatusPending, forKey: shareImportStatusKey)
        userDefaults?.synchronize()
    }

    /// Rétrocompat : ancienne API (fichier seul, sans JSON) — non utilisée par le nouveau flux.
    static func saveImage(_ imageData: Data) -> String? {
        guard let dir = sharedImagesURL else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = dir.appendingPathComponent(fileName)
        do {
            try imageData.write(to: fileURL)
            userDefaults?.set(fileName, forKey: "amisa.sharedImagePayload")
            userDefaults?.synchronize()
            return fileName
        } catch {
            return nil
        }
    }
}

enum ShareExtensionStorageError: Error {
    case containerUnavailable
}
