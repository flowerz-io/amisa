//
//  PickedImageAnalysisHandler.swift
//  Amisa
//
//  Point d’entrée unique pour une image choisie (caméra, récents, galerie, partage).
//

import SwiftUI
import UIKit

@MainActor
enum PickedImageAnalysisHandler {
    private static let jpegQuality: CGFloat = 0.88
    private static let maxJPEGBytes = 12 * 1024 * 1024

    /// Prépare l’image, ferme la caméra, ouvre Review (début du flow d’analyse).
    @discardableResult
    static func handlePickedImage(_ image: UIImage, router: Router) -> Bool {
        guard let data = preparedJPEGData(from: image) else {
            print("[PICK_IMAGE] failed: JPEG encoding")
            return false
        }
        guard let fileName = ImagePersistenceService.shared.saveImage(data) else {
            print("[PICK_IMAGE] failed: saveImage — appGroup:", AmisaAppGroup.identifier,
                  "container:", ImagePersistenceService.debugContainerPath ?? "nil")
            return false
        }

        print("[PICK_IMAGE] success file:", fileName, "bytes:", data.count)
        router.showCameraCapture = false
        router.navigateToSharedImportReview(
            payload: SharedImportPayload(imageFileName: fileName)
        )
        return true
    }

    @discardableResult
    static func handlePickedImageData(_ data: Data, router: Router) -> Bool {
        guard let image = UIImage(data: data) else {
            print("[PICK_IMAGE] failed: invalid image data")
            return false
        }
        return handlePickedImage(image, router: router)
    }

    private static func preparedJPEGData(from image: UIImage) -> Data? {
        let normalized = image.amisaNormalizedForUpload()
        var quality = jpegQuality
        var data = normalized.jpegData(compressionQuality: quality)
        while let d = data, d.count > maxJPEGBytes, quality > 0.35 {
            quality -= 0.12
            data = normalized.jpegData(compressionQuality: quality)
        }
        return data
    }
}

// MARK: - Orientation

extension UIImage {
    func amisaNormalizedForUpload() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Debug

extension ImagePersistenceService {
    static var debugContainerPath: String? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )?.path
    }
}
