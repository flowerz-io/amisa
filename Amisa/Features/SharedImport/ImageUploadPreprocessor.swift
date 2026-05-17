//
//  ImageUploadPreprocessor.swift
//  Balibu
//
//  Préparation JPEG pour POST /analyze-search (taille serveur, stabilité).
//

import UIKit

enum ImageUploadPreprocessorError: LocalizedError {
    case couldNotEncode

    var errorDescription: String? {
        switch self {
        case .couldNotEncode:
            return "Impossible de préparer l’image pour l’envoi."
        }
    }
}

/// Redimensionnement + JPEG avec boucle de compression pour viser un payload léger.
enum ImageUploadPreprocessor {
    /// Largeur max sur le **plus long** côté (px), avant envoi `analyze-search`.
    static let maxLongSidePixels: CGFloat = 1024
    /// Alias historique — conservé pour compatibilité ; correspond au côté long.
    static var maxPixelWidth: CGFloat { maxLongSidePixels }
    static let initialCompressionQuality: CGFloat = 0.75
    /// Cible confort pour éviter 413 côté proxy.
    static let targetMaxBytes = 500_000
    /// Plafond dur avant d’abandonner la réduction.
    static let hardMaxBytes = 950_000
    static let minCompressionQuality: CGFloat = 0.35
    static let minPixelWidth: CGFloat = 480

    /// Retourne des données JPEG prêtes pour `analyze-search`.
    static func prepareForUpload(_ image: UIImage) throws -> Data {
        let scaled = resizeIfNeeded(image, maxLongSide: maxLongSidePixels)
        var quality = initialCompressionQuality
        var data = scaled.jpegData(compressionQuality: quality) ?? Data()
        if data.isEmpty { throw ImageUploadPreprocessorError.couldNotEncode }

        var working = scaled
        var w = min(
            maxLongSidePixels,
            max(
                working.size.width * working.scale,
                working.size.height * working.scale,
                1
            )
        )

        while data.count > targetMaxBytes {
            if quality > minCompressionQuality + 0.04 {
                quality -= 0.06
                if let d = working.jpegData(compressionQuality: quality), !d.isEmpty {
                    data = d
                }
                if data.count <= targetMaxBytes { break }
            }

            if w > minPixelWidth + 40 {
                w *= 0.85
                working = resizeIfNeeded(image, maxLongSide: w)
                quality = min(initialCompressionQuality, quality + 0.05)
                if let d = working.jpegData(compressionQuality: quality), !d.isEmpty {
                    data = d
                }
            } else if quality > minCompressionQuality {
                quality -= 0.05
                if let d = working.jpegData(compressionQuality: quality), !d.isEmpty {
                    data = d
                }
            } else {
                break
            }

            if data.count <= hardMaxBytes { break }
        }

        if data.isEmpty { throw ImageUploadPreprocessorError.couldNotEncode }

        let kb = Double(data.count) / 1024.0
        let mb = kb / 1024.0
        let sizeStr = mb >= 0.01 ? String(format: "%.2f MB", mb) : String(format: "%.0f KB", kb)
        #if DEBUG
        print("[IMAGE_UPLOAD] payload=\(data.count) bytes (~\(sizeStr)) quality=\(quality) longSide≤\(Int(maxLongSidePixels))px")
        #else
        NSLog("[IMAGE_UPLOAD] %llu bytes (~%@)", UInt64(data.count), sizeStr)
        #endif
        return data
    }

    /// Agrandit si bonne orientation : le **plus long** côté ne dépasse pas `maxLongSide` px.
    private static func resizeIfNeeded(_ image: UIImage, maxLongSide: CGFloat) -> UIImage {
        let w = image.size.width * image.scale
        let h = image.size.height * image.scale
        let longSide = max(w, h)
        guard longSide > maxLongSide, maxLongSide > 0 else { return image }

        let ratio = maxLongSide / longSide
        let newSize = CGSize(width: max(1, w * ratio), height: max(1, h * ratio))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
