//
//  SharedInputResolver.swift
//  BalibuShareExtension
//
//  Détection priorisée des contenus réellement reçus par la Share Extension.
//

import Foundation
import UniformTypeIdentifiers
import UIKit

// MARK: - Plateforme source

enum SharedSourcePlatform {
    case instagram
    case pinterest
    case tiktok
    case generic
}

enum SharedSourcePlatformDetector {
    static func detect(from providers: [NSItemProvider], url: URL?) -> SharedSourcePlatform {
        if let url {
            let host = url.host?.lowercased() ?? "(nil)"
            print("[SHARE_URL_HOST] \(host)")

            if isTikTok(url) {
                print("[SHARE_SOURCE_TIKTOK_DETECTED]")
                print("[SHARE_SOURCE_PLATFORM] tiktok")
                return .tiktok
            }
            if isInstagram(url) {
                print("[SHARE_SOURCE_PLATFORM] instagram")
                return .instagram
            }
            if isPinterest(url) {
                print("[SHARE_SOURCE_PLATFORM] pinterest")
                return .pinterest
            }
            print("[SHARE_SOURCE_PLATFORM] generic (host=\(host))")
        }
        // Certaines apps injectent leur nom dans le suggestedName ou les typeIdentifiers.
        for provider in providers {
            let types = provider.registeredTypeIdentifiers.joined(separator: " ").lowercased()
            if types.contains("tiktok") {
                print("[SHARE_SOURCE_TIKTOK_DETECTED] (via typeIdentifier)")
                print("[SHARE_SOURCE_PLATFORM] tiktok")
                return .tiktok
            }
            if types.contains("instagram") { return .instagram }
            if types.contains("pinterest") { return .pinterest }
        }
        return .generic
    }

    static func isTikTok(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "tiktok.com"
            || host == "www.tiktok.com"
            || host == "m.tiktok.com"
            || host == "vm.tiktok.com"
            || host.hasSuffix(".tiktok.com")
    }

    static func isInstagram(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "instagram.com"
            || host == "www.instagram.com"
            || host == "m.instagram.com"
            || host == "instagr.am"
            || host.hasSuffix(".instagram.com")
    }

    static func isPinterest(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "pinterest.com"
            || host == "www.pinterest.com"
            || host == "pin.it"
            || host.hasSuffix(".pinterest.com")
    }
}

// MARK: - Résolution d'entrée

enum SharedInputKind {
    case image(UIImage)
    case video(URL)
    case url(URL)
    case unknown
}

struct SharedInputResolution {
    let kind: SharedInputKind
    let platform: SharedSourcePlatform
    let previewImage: UIImage?
}

final class SharedInputResolver {
    func resolve(from context: NSExtensionContext?) async -> SharedInputResolution {
        guard let context,
              let items = context.inputItems as? [NSExtensionItem],
              !items.isEmpty else {
            print("[SHARE_INPUT_UNKNOWN]")
            return SharedInputResolution(kind: .unknown, platform: .generic, previewImage: nil)
        }

        var firstImage: UIImage?
        var firstVideoURL: URL?
        var firstURL: URL?
        var fallbackPreviewImage: UIImage?
        var allProviders: [NSItemProvider] = []

        for item in items {
            guard let attachments = item.attachments else { continue }
            allProviders.append(contentsOf: attachments)
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

        let platform = SharedSourcePlatformDetector.detect(from: allProviders, url: firstURL)
        logPlatform(platform)

        if let firstImage {
            print("[SHARE_INPUT_IMAGE]")
            logPlatformImageFound(platform, found: true)
            return SharedInputResolution(kind: .image(firstImage), platform: platform, previewImage: nil)
        }
        if let firstVideoURL {
            print("[SHARE_INPUT_VIDEO]")
            logPlatformVideoFound(platform)
            return SharedInputResolution(kind: .video(firstVideoURL), platform: platform, previewImage: fallbackPreviewImage)
        }
        if let firstURL {
            print("[SHARE_INPUT_URL]")
            logPlatformImageFound(platform, found: fallbackPreviewImage != nil)
            return SharedInputResolution(kind: .url(firstURL), platform: platform, previewImage: fallbackPreviewImage)
        }

        print("[SHARE_INPUT_UNKNOWN]")
        return SharedInputResolution(kind: .unknown, platform: platform, previewImage: nil)
    }

    // MARK: - Logs plateforme

    private func logPlatform(_ platform: SharedSourcePlatform) {
        switch platform {
        case .tiktok:    print("[SHARE_SOURCE_TIKTOK]")
        case .instagram: print("[SHARE_SOURCE_INSTAGRAM]")
        case .pinterest: print("[SHARE_SOURCE_PINTEREST]")
        case .generic:   print("[SHARE_SOURCE_GENERIC]")
        }
    }

    private func logPlatformImageFound(_ platform: SharedSourcePlatform, found: Bool) {
        guard platform == .tiktok else { return }
        print(found ? "[TIKTOK_PREVIEW_IMAGE_FOUND]" : "[TIKTOK_FALLBACK_USED]")
    }

    private func logPlatformVideoFound(_ platform: SharedSourcePlatform) {
        guard platform == .tiktok else { return }
        print("[TIKTOK_NATIVE_VIDEO_FOUND]")
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
        // loadPreviewImage fonctionne sur tout type de provider (URL incluse),
        // iOS peut fournir une miniature même pour un lien TikTok / Instagram.
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
