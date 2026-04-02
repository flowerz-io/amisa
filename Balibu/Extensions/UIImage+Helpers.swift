//
//  UIImage+Helpers.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import UIKit

extension UIImage {
    /// Compresse l'image pour envoi au backend (JPEG max 1MB).
    func compressedForUpload(maxSizeKB: Int = 1024) -> Data? {
        var compression: CGFloat = 0.9
        guard var data = jpegData(compressionQuality: compression) else { return nil }
        let maxBytes = maxSizeKB * 1024
        while data.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            guard let newData = jpegData(compressionQuality: compression) else { return data }
            data = newData
        }
        return data
    }
}
