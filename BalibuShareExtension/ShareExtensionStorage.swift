//
//  ShareExtensionStorage.swift
//  BalibuShareExtension
//
//  Écriture App Group alignée sur ShareStorageService côté app.
//

import Foundation

enum ShareExtensionStorage {
    static let appGroupIdentifier = "group.flowerz.io.Balibu"
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
        "balibu.importPayload.\(id.uuidString)"
    }

    private static let pendingImportIdKey = "balibu.pendingImportId"

    /// Enregistre le JPEG final + métadonnées JSON pour le deep link `balibu://shared-import?id=`.
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
            userDefaults?.set(fileName, forKey: "balibu.sharedImagePayload")
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
