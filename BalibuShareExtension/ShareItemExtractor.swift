//
//  ShareItemExtractor.swift
//  BalibuShareExtension
//
//  Extrait les images du NSExtensionContext.
//

import UIKit
import UniformTypeIdentifiers
import MobileCoreServices

enum ShareItemExtractor {
    /// Extrait la première image disponible du contexte de partage.
    static func extractImage(from context: NSExtensionContext?) async -> Data? {
        guard let context = context,
              let items = context.inputItems as? [NSExtensionItem],
              !items.isEmpty else { return nil }

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if let data = await loadImage(from: provider) {
                    return data
                }
            }
        }
        return nil
    }

    private static func loadImage(from provider: NSItemProvider) async -> Data? {
        let imageTypes: [String] = [
            UTType.image.identifier,
            UTType.jpeg.identifier,
            UTType.png.identifier,
            UTType.webP.identifier,
            kUTTypeImage as String
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

    private static func extractImageData(from item: NSSecureCoding?) -> Data? {
        if let data = item as? Data { return data }
        if let url = item as? URL { return try? Data(contentsOf: url) }
        if let image = item as? UIImage { return image.jpegData(compressionQuality: 0.85) }
        return nil
    }
}
