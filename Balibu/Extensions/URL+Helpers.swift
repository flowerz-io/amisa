//
//  URL+Helpers.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import Foundation

extension URL {
    /// Vérifie si l'URL pointe vers une image.
    var isImage: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "webp", "gif"]
        return imageExtensions.contains(pathExtension.lowercased())
    }
}
