//
//  ShareExtensionStorage.swift
//  AmisaShareExtension
//
//  Écriture App Group alignée sur l’app principale (`AmisaAppGroup.identifier`).
//

import Foundation
import UIKit

enum ShareExtensionStorage {
    /// Doit être identique à `AmisaAppGroup.identifier` et aux entitlements.
    static let appGroupIdentifier = "group.io.flowerz.amisa"
    private static let sharedImagesDirectory = "SharedImages"
    private static let maxJPEGBytes = 12 * 1024 * 1024

    private static var containerURL: URL? {
        let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
        if url == nil {
            print("[SHARE_EXTENSION] containerURL: nil for appGroup:", appGroupIdentifier)
        }
        return url
    }

    private static var sharedImagesURL: URL? {
        containerURL?.appendingPathComponent(sharedImagesDirectory, isDirectory: true)
    }

    private static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private static func payloadKey(for id: UUID) -> String {
        "amisa.importPayload.\(id.uuidString)"
    }

    private static let pendingImportIdKey = "amisa.pendingImportId"
    private static let shareImportStatusKey = "amisa.shareImportStatus"
    private static let shareImportStatusPending = "pending"

    /// JPEG dans `SharedImages` uniquement (flux session Railway).
    static func saveJPEGToSharedImagesOnly(_ imageData: Data) throws -> String {
        print("[SHARE_EXTENSION] appGroup:", appGroupIdentifier)
        guard let dir = sharedImagesURL else {
            throw ShareExtensionStorageError.containerUnavailable
        }
        print("[SHARE_EXTENSION] containerURL:", dir.deletingLastPathComponent().absoluteString)

        let prepared = preparedJPEGData(from: imageData)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = dir.appendingPathComponent(fileName)
        do {
            try prepared.write(to: fileURL, options: .atomic)
            print("[SHARE_EXTENSION] image write success:", fileURL.path, "bytes:", prepared.count)
            return fileName
        } catch {
            print("[SHARE_EXTENSION] storage error:", error)
            throw ShareExtensionStorageError.writeFailed(fileURL.path, error)
        }
    }

    static func saveSessionResultJSON(_ data: Data, sessionId: String) throws -> String {
        let fileName = "session-\(sessionId).json"
        guard let base = containerURL else {
            throw ShareExtensionStorageError.containerUnavailable
        }
        let dir = base.appendingPathComponent("SessionResults", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName)
        try data.write(to: url)
        return fileName
    }

    private static let continuityDirectory = "ContinuitySnapshots"

    static func saveContinuitySnapshot(_ data: Data, sessionId: String) throws -> String {
        let fileName = "continuity-\(sessionId).json"
        guard let base = containerURL else {
            throw ShareExtensionStorageError.containerUnavailable
        }
        let dir = base.appendingPathComponent(continuityDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: dir.appendingPathComponent(fileName))
        return fileName
    }

    static func saveImport(payload: SharedImportPayload, imageData: Data) throws {
        guard let dir = sharedImagesURL else {
            throw ShareExtensionStorageError.containerUnavailable
        }
        let prepared = preparedJPEGData(from: imageData)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(payload.imageFileName)
        try prepared.write(to: fileURL, options: .atomic)
        print("[SHARE_EXTENSION] import write success:", fileURL.path)

        let encoded = try JSONEncoder().encode(payload)
        userDefaults?.set(encoded, forKey: payloadKey(for: payload.id))
        userDefaults?.set(payload.id.uuidString, forKey: pendingImportIdKey)
        userDefaults?.set(shareImportStatusPending, forKey: shareImportStatusKey)
        userDefaults?.synchronize()
    }

    static func saveImage(_ imageData: Data) -> String? {
        try? saveJPEGToSharedImagesOnly(imageData)
    }

    // MARK: - Compression

    private static func preparedJPEGData(from raw: Data) -> Data {
        if raw.count <= maxJPEGBytes, UIImage(data: raw) != nil {
            return raw
        }
        guard let image = UIImage(data: raw) else { return raw }
        var quality: CGFloat = 0.88
        var data = image.jpegData(compressionQuality: quality) ?? raw
        while data.count > maxJPEGBytes, quality > 0.35 {
            quality -= 0.12
            data = image.jpegData(compressionQuality: quality) ?? data
        }
        print("[SHARE_EXTENSION] compressed JPEG bytes:", data.count)
        return data
    }
}

enum ShareExtensionStorageError: Error {
    case containerUnavailable
    case writeFailed(String, Error)
}

extension ShareExtensionStorageError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return "Conteneur App Group indisponible (\(ShareExtensionStorage.appGroupIdentifier))."
        case .writeFailed(let path, let error):
            return "Écriture impossible (\(path)) : \(error.localizedDescription)"
        }
    }
}
