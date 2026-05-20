//
//  ColorAnalysisService.swift
//  Amisa
//
//  Signatures couleur dominantes (async, cache mémoire) + score de similarité 0…100.
//  Ne bloque pas l’affichage initial : appel après premier rendu pour re-classement progressif.
//

import Foundation
import simd
import UIKit

enum ColorAnalysisService {
    private actor URLSignatureCache {
        private var storage: [String: [SIMD3<Float>]] = [:]

        func value(for key: String) -> [SIMD3<Float>]? {
            storage[key]
        }

        func set(_ value: [SIMD3<Float>], for key: String) {
            storage[key] = value
        }
    }

    private static let urlCache = URLSignatureCache()

    // MARK: - Extraction (image locale)

    /// Couleurs dominantes (RGB linéarisé 0…1), typiquement 2 buckets les plus fréquents.
    static func extractDominantColors(from image: UIImage, maxColors: Int = 2) -> [SIMD3<Float>] {
        extractRGBBuckets(from: image, maxColors: maxColors)
    }

    /// Extraction depuis une vignette réseau ; cache URL → signature.
    static func extractDominantColors(fromListingURL url: URL?) async -> [SIMD3<Float>] {
        guard let url else { return [] }
        let key = url.absoluteString
        if let hit = await urlCache.value(for: key) {
            return hit
        }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else { return [] }

        let sig = await Task.detached(priority: .utility) {
            extractRGBBuckets(from: uiImage, maxColors: 2)
        }.value

        await urlCache.set(sig, for: key)
        #if DEBUG
        print("[COLOR_MATCH] extracted listing url=\(key.prefix(48))… buckets=\(sig.count)")
        #endif
        return sig
    }

    // MARK: - Similarité

    static func normalizedColorDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        simd_length(a - b) / max(0.0001, sqrt(3))
    }

    /// Score 0…100 (100 = très proche des couleurs de référence).
    static func computeColorSimilarity(reference: [SIMD3<Float>], listing: [SIMD3<Float>]) -> Double {
        guard !reference.isEmpty, !listing.isEmpty else { return 72 }
        var sum: Float = 0
        for r in reference {
            let best = listing.map { normalizedColorDistance(r, $0) }.min() ?? 1
            sum += best
        }
        let avg = sum / Float(reference.count)
        let s = (1 - min(avg, 1)) * 100
        #if DEBUG
        print("[SIMILARITY_SCORE] refBuckets=\(reference.count) listBuckets=\(listing.count) score=\(String(format: "%.1f", s))")
        #endif
        return Double(s)
    }

    // MARK: - Core (18×18, buckets teinte — aligné ImagePaletteExtractor)

    private static func extractRGBBuckets(from image: UIImage, maxColors: Int) -> [SIMD3<Float>] {
        let side = 18
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        guard let cgImage = resized.cgImage else { return [] }

        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: side, height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var buckets = [Int: [(r: CGFloat, g: CGFloat, b: CGFloat, h: CGFloat, s: CGFloat, br: CGFloat)]]()

        for i in stride(from: 0, to: side * side * 4, by: 4) {
            let r = CGFloat(pixels[i]) / 255.0
            let g = CGFloat(pixels[i + 1]) / 255.0
            let b = CGFloat(pixels[i + 2]) / 255.0
            var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
            UIColor(red: r, green: g, blue: b, alpha: 1)
                .getHue(&h, saturation: &s, brightness: &br, alpha: &a)
            guard s > 0.14, br > 0.15, br < 0.97 else { continue }
            let bucket = Int(h * 12) % 12
            buckets[bucket, default: []].append((r, g, b, h, s, br))
        }

        let sorted = buckets.sorted { $0.value.count > $1.value.count }
        var vectors: [SIMD3<Float>] = []
        for (_, samples) in sorted.prefix(max(1, maxColors)) {
            guard !samples.isEmpty else { continue }
            let n = CGFloat(samples.count)
            let avgr = Float(samples.map(\.r).reduce(0, +) / n)
            let avgg = Float(samples.map(\.g).reduce(0, +) / n)
            let avgb = Float(samples.map(\.b).reduce(0, +) / n)
            vectors.append(SIMD3(avgr, avgg, avgb))
            if vectors.count >= maxColors { break }
        }
        return vectors
    }
}
