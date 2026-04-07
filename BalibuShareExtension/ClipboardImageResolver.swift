//
//  ClipboardImageResolver.swift
//  BalibuShareExtension
//
//  Résolution d'image depuis le presse-papiers sans extraction externe.
//

import Foundation
import UIKit

final class ClipboardImageResolver {
    func resolveImage() -> UIImage? {
        let pasteboard = UIPasteboard.general

        if let image = pasteboard.image {
            return image
        }

        // Fallback léger : URL locale d’image déjà présente dans le presse-papiers.
        if let url = pasteboard.url,
           url.isFileURL,
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }

        return nil
    }
}
