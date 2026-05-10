//
//  ImagePaletteExtractor.swift
//  Balibu
//
//  Extraction de palette couleur dominante depuis une image produit.
//  Utilisée pour colorer dynamiquement le texte dans les cartes listing.
//
//  Architecture :
//  - Actor singleton (thread-safe, cache en mémoire)
//  - Extraction sur thread background via Task.detached
//  - Resize à 18×18 px pour vitesse maximale
//  - Quantisation par bucket de teinte (12 × 30°)
//  - Validation luminosité : texte toujours lisible sur fond sombre
//

import UIKit
import SwiftUI

// MARK: - ListingColorPalette

struct ListingColorPalette: Sendable {
    /// Couleur principale — titre du produit
    let primary: Color
    /// Couleur secondaire — marque/label
    let secondary: Color

    static let fallback = ListingColorPalette(
        primary: .white,
        secondary: .white.opacity(0.72)
    )
}

// MARK: - ImagePaletteExtractor

actor ImagePaletteExtractor {

    static let shared = ImagePaletteExtractor()

    private var cache: [String: ListingColorPalette] = [:]

    private init() {}

    // MARK: - Public API

    /// Retourne la palette dominante pour une URL.
    /// Cache hit = instantané. Cache miss = réseau + extraction async.
    func palette(for url: URL?) async -> ListingColorPalette {
        guard let url else { return .fallback }
        let key = url.absoluteString

        if let cached = cache[key] { return cached }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else { return .fallback }

        let result = await Task.detached(priority: .background) {
            Self.extractSync(from: uiImage)
        }.value

        cache[key] = result
        return result
    }

    // MARK: - Core extraction (off-actor, background thread)

    private static func extractSync(from image: UIImage) -> ListingColorPalette {
        let side = 18

        // ── Resize vers une vignette 18×18 px @1x ───────────────────────────
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        )
        let resized = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        guard let cgImage = resized.cgImage else { return .fallback }

        // ── Lecture des pixels ───────────────────────────────────────────────
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: side, height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .fallback }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        // ── Quantisation par bucket de teinte (12 × 30°) ────────────────────
        var buckets = [Int: [(h: CGFloat, s: CGFloat, b: CGFloat)]]()

        for i in stride(from: 0, to: side * side * 4, by: 4) {
            let r = CGFloat(pixels[i])     / 255.0
            let g = CGFloat(pixels[i + 1]) / 255.0
            let b = CGFloat(pixels[i + 2]) / 255.0

            var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
            UIColor(red: r, green: g, blue: b, alpha: 1)
                .getHue(&h, saturation: &s, brightness: &br, alpha: &a)

            // Exclure les gris, noirs purs et blancs purs
            guard s > 0.18, br > 0.18, br < 0.96 else { continue }

            let bucket = Int(h * 12) % 12
            buckets[bucket, default: []].append((h: h, s: s, b: br))
        }

        // ── Tri par fréquence → 2 couleurs dominantes ───────────────────────
        let sorted = buckets.sorted { $0.value.count > $1.value.count }

        var extracted: [UIColor] = []
        for (_, samples) in sorted.prefix(2) {
            let count = CGFloat(samples.count)
            let avgH = samples.map(\.h).reduce(0, +) / count
            // Boost léger de saturation pour l'aspect vivant
            let avgS = min(samples.map(\.s).reduce(0, +) / count * 1.12, 1.0)
            // Assurer une luminosité suffisante pour texte lisible sur fond sombre
            let rawB = samples.map(\.b).reduce(0, +) / count
            let avgB = max(min(rawB * 1.18, 0.96), 0.62)

            extracted.append(UIColor(hue: avgH, saturation: avgS, brightness: avgB, alpha: 1))
        }

        // ── Fallback si aucune couleur saturée trouvée ───────────────────────
        guard !extracted.isEmpty else { return .fallback }

        let primary = Color(uiColor: extracted[0])
        let secondary: Color = extracted.count > 1
            ? Color(uiColor: extracted[1]).opacity(0.82)
            : primary.opacity(0.72)

        return ListingColorPalette(primary: primary, secondary: secondary)
    }
}
