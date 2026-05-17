//
//  ImageUploadPreprocessor.swift
//  AmisaShareExtension
//
//  Même politique que l’app : 1024 px (côté long), JPEG ~0.75, logs taille.
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

enum ImageUploadPreprocessor {
    static let maxLongSidePixels: CGFloat = 1024
    static var maxPixelWidth: CGFloat { maxLongSidePixels }
    static let initialCompressionQuality: CGFloat = 0.75
    static let targetMaxBytes = 500_000
    static let hardMaxBytes = 950_000
    static let minCompressionQuality: CGFloat = 0.35
    static let minPixelWidth: CGFloat = 480

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
        print("[IMAGE_UPLOAD] [ShareExt] payload=\(data.count) bytes (~\(sizeStr)) quality=\(quality) longSide≤\(Int(maxLongSidePixels))px")
        #else
        NSLog("[IMAGE_UPLOAD] [ShareExt] %llu bytes (~%@)", UInt64(data.count), sizeStr)
        #endif
        return data
    }

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
