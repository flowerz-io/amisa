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
    /// Largeur max côté pixel (points × scale pris en compte via `UIImage`).
    static let maxPixelWidth: CGFloat = 1200
    static let initialCompressionQuality: CGFloat = 0.75
    /// Cible confort pour éviter 413 côté proxy.
    static let targetMaxBytes = 500_000
    /// Plafond dur avant d’abandonner la réduction.
    static let hardMaxBytes = 950_000
    static let minCompressionQuality: CGFloat = 0.35
    static let minPixelWidth: CGFloat = 480

    /// Retourne des données JPEG prêtes pour `analyze-search`.
    static func prepareForUpload(_ image: UIImage) throws -> Data {
        let scaled = resizeIfNeeded(image, maxWidth: maxPixelWidth)
        var quality = initialCompressionQuality
        var data = scaled.jpegData(compressionQuality: quality) ?? Data()
        if data.isEmpty { throw ImageUploadPreprocessorError.couldNotEncode }

        var working = scaled
        var w = min(maxPixelWidth, max(working.size.width * working.scale, 1))

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
                working = resizeIfNeeded(image, maxWidth: w)
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
        return data
    }

    private static func resizeIfNeeded(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        let w = image.size.width * image.scale
        let h = image.size.height * image.scale
        guard w > maxWidth, maxWidth > 0 else { return image }

        let ratio = maxWidth / w
        let newSize = CGSize(width: maxWidth, height: max(1, h * ratio))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
