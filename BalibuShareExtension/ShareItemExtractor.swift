//
//  ShareItemExtractor.swift
//  BalibuShareExtension
//
//  Extrait image ou URL du contexte de partage.
//

import MobileCoreServices
import UniformTypeIdentifiers
import UIKit

enum ShareExtractedContent {
    /// Image brute (fichier joint).
    case image(Data)
    /// Lien vers une page (Pinterest, Instagram web, etc.).
    case link(URL)
}

enum ShareItemExtractor {
    /// Priorité : première image jointe ; sinon première URL exploitable.
    static func extractContent(from context: NSExtensionContext?) async -> ShareExtractedContent? {
        guard let context = context,
              let items = context.inputItems as? [NSExtensionItem],
              !items.isEmpty else { return nil }

        var firstURL: URL?

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if let data = await loadImage(from: provider) {
                    return .image(data)
                }
                if let url = await loadURL(from: provider) {
                    if firstURL == nil { firstURL = url }
                }
            }
        }

        if let url = firstURL {
            return .link(url)
        }
        return nil
    }

    /// Première image disponible (compat).
    static func extractImage(from context: NSExtensionContext?) async -> Data? {
        guard let content = await extractContent(from: context) else { return nil }
        if case .image(let data) = content { return data }
        return nil
    }

    private static func loadImage(from provider: NSItemProvider) async -> Data? {
        let imageTypes: [String] = [
            UTType.image.identifier,
            UTType.jpeg.identifier,
            UTType.png.identifier,
            UTType.webP.identifier,
            kUTTypeImage as String,
        ]

        for typeId in imageTypes {
            if provider.hasItemConformingToTypeIdentifier(typeId) {
                return await withCheckedContinuation { continuation in
                    provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
                        let data = extractImageData(from: item)
                        continuation.resume(returning: data)
                    }
                }
            }
        }
        return nil
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        let urlTypes = [UTType.url.identifier, "public.url"]

        for typeId in urlTypes {
            if provider.hasItemConformingToTypeIdentifier(typeId) {
                return await withCheckedContinuation { continuation in
                    provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
                        if let url = item as? URL {
                            continuation.resume(returning: url)
                        } else if let s = item as? String, let url = URL(string: s) {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }
        }
        return nil
    }

    private static func extractImageData(from item: NSSecureCoding?) -> Data? {
        if let data = item as? Data { return data }
        if let url = item as? URL { return try? Data(contentsOf: url) }
        if let image = item as? UIImage { return image.jpegData(compressionQuality: 0.85) }
        return nil
    }
}
