//
//  SharedInputResolver.swift
//  BalibuShareExtension
//
//  Détection priorisée des contenus réellement reçus par la Share Extension.
//

import Foundation
import UniformTypeIdentifiers
import UIKit

enum SharedInputKind {
    case image(UIImage)
    case video(URL)
    case url(URL)
    case unknown
}

struct SharedInputResolution {
    let kind: SharedInputKind
    let previewImage: UIImage?
}

final class SharedInputResolver {
    func resolve(from context: NSExtensionContext?) async -> SharedInputResolution {
        guard let context,
              let items = context.inputItems as? [NSExtensionItem],
              !items.isEmpty else {
            print("[SHARE_INPUT_UNKNOWN]")
            return SharedInputResolution(kind: .unknown, previewImage: nil)
        }

        var firstImage: UIImage?
        var firstVideoURL: URL?
        var firstURL: URL?
        var fallbackPreviewImage: UIImage?

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if firstImage == nil, let image = await loadImage(from: provider) {
                    firstImage = image
                }
                if firstVideoURL == nil, let videoURL = await loadVideoURL(from: provider) {
                    firstVideoURL = videoURL
                }
                if firstURL == nil, let url = await loadURL(from: provider) {
                    firstURL = url
                }
                if fallbackPreviewImage == nil, let preview = await loadPreviewImage(from: provider) {
                    fallbackPreviewImage = preview
                }
            }
        }

        if let firstImage {
            print("[SHARE_INPUT_IMAGE]")
            return SharedInputResolution(kind: .image(firstImage), previewImage: nil)
        }
        if let firstVideoURL {
            print("[SHARE_INPUT_VIDEO]")
            return SharedInputResolution(kind: .video(firstVideoURL), previewImage: nil)
        }
        if let firstURL {
            print("[SHARE_INPUT_URL]")
            return SharedInputResolution(kind: .url(firstURL), previewImage: fallbackPreviewImage)
        }

        print("[SHARE_INPUT_UNKNOWN]")
        return SharedInputResolution(kind: .unknown, previewImage: nil)
    }

    private func loadImage(from provider: NSItemProvider) async -> UIImage? {
        let imageTypes = [
            UTType.image.identifier,
            UTType.jpeg.identifier,
            UTType.png.identifier,
            UTType.webP.identifier,
            "public.image",
        ]
        for typeId in imageTypes where provider.hasItemConformingToTypeIdentifier(typeId) {
            return await withCheckedContinuation { continuation in
                provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
                    continuation.resume(returning: Self.image(from: item))
                }
            }
        }
        return nil
    }

    private func loadPreviewImage(from provider: NSItemProvider) async -> UIImage? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadPreviewImage(options: nil) { image, _ in
                continuation.resume(returning: image as? UIImage)
            }
        }
    }

    private func loadVideoURL(from provider: NSItemProvider) async -> URL? {
        let videoTypes = [
            UTType.movie.identifier,
            UTType.video.identifier,
            "public.movie",
            "public.video",
        ]
        for typeId in videoTypes where provider.hasItemConformingToTypeIdentifier(typeId) {
            return await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: typeId) { url, _ in
                    guard let url else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(url.pathExtension)")
                    do {
                        try? FileManager.default.removeItem(at: tempURL)
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        continuation.resume(returning: tempURL)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
        return nil
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        let urlTypes = [UTType.url.identifier, "public.url"]
        for typeId in urlTypes where provider.hasItemConformingToTypeIdentifier(typeId) {
            return await withCheckedContinuation { continuation in
                provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
                    if let url = item as? URL {
                        continuation.resume(returning: url)
                    } else if let string = item as? String, let url = URL(string: string) {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
        return nil
    }

    private static func image(from item: NSSecureCoding?) -> UIImage? {
        if let image = item as? UIImage { return image }
        if let data = item as? Data { return UIImage(data: data) }
        if let url = item as? URL, let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
}
