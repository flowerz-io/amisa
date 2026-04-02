//
//  ShareExtensionStorage.swift
//  BalibuShareExtension
//
//  Stockage App Group pour passer l'image de l'extension à l'app principale.
//  Duplique la logique minimale car l'extension ne partage pas le code de l'app.
//

import Foundation

enum ShareExtensionStorage {
    static let appGroupIdentifier = "group.flowerz.io.Balibu"
    private static let payloadKey = "balibu.sharedImagePayload"
    private static let sharedImagesDirectory = "SharedImages"

    private static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private static var sharedImagesURL: URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }
        return container.appendingPathComponent(sharedImagesDirectory)
    }

    /// Enregistre l'image dans le conteneur App Group et sauvegarde le nom de fichier.
    static func saveImage(_ imageData: Data) -> String? {
        guard let dir = sharedImagesURL else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = dir.appendingPathComponent(fileName)
        do {
            try imageData.write(to: fileURL)
            userDefaults?.set(fileName, forKey: payloadKey)
            userDefaults?.synchronize()
            return fileName
        } catch {
            return nil
        }
    }
}
