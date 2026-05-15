//
//  ImagePersistenceService.swift
//  Balibu
//
//  Persistance des images dans le conteneur App Group.
//

import Foundation
import UIKit

final class ImagePersistenceService {
    static let shared = ImagePersistenceService()

    static let appGroupIdentifier = ShareStorageService.appGroupIdentifier
    private let sharedImagesDirectory = "SharedImages"

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)
    }

    private var sharedImagesURL: URL? {
        containerURL?.appending(path: sharedImagesDirectory)
    }

    private init() {
        createDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() {
        guard let url = sharedImagesURL else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Enregistre une image et retourne le nom du fichier.
    func saveImage(_ imageData: Data) -> String? {
        guard let dir = sharedImagesURL else { return nil }
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = dir.appending(path: fileName)
        do {
            try imageData.write(to: fileURL)
            return fileName
        } catch {
            return nil
        }
    }

    /// Charge une image par son nom de fichier.
    func loadImage(fileName: String) -> Data? {
        guard let dir = sharedImagesURL else { return nil }
        let fileURL = dir.appending(path: fileName)
        return try? Data(contentsOf: fileURL)
    }

    /// Charge une image en UIImage.
    func loadUIImage(fileName: String) -> UIImage? {
        guard let data = loadImage(fileName: fileName) else { return nil }
        return UIImage(data: data)
    }

    /// Supprime une image après utilisation.
    func deleteImage(fileName: String) {
        guard let dir = sharedImagesURL else { return }
        let fileURL = dir.appending(path: fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Chemin complet pour un fichier (utilisé par l'extension).
    func fullPath(for fileName: String) -> URL? {
        sharedImagesURL?.appending(path: fileName)
    }

    /// Supprime une image temporaire partagée.
    func cleanupTemporaryImage(at url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Persiste une miniature pour l'historique. Retourne l'URL de la thumbnail.
    func persistThumbnail(for session: SearchSession) -> URL? {
        guard let fileName = session.imageFileName,
              let data = loadImage(fileName: fileName),
              let image = UIImage(data: data) else { return nil }
        let thumbSize = CGSize(width: 120, height: 120)
        UIGraphicsBeginImageContextWithOptions(thumbSize, true, 0)
        image.draw(in: CGRect(origin: .zero, size: thumbSize))
        let thumb = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let thumbData = thumb?.jpegData(compressionQuality: 0.7) else { return nil }
        let thumbName = "thumb_\(session.id.uuidString).jpg"
        guard let dir = sharedImagesURL else { return nil }
        let thumbURL = dir.appending(path: thumbName)
        try? thumbData.write(to: thumbURL)
        return thumbURL
    }
}
