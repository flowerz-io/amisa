//
//  AdaptiveCardTextOverlay.swift
//  Balibu
//
//  Overlay de lisibilité adaptatif pour cartes image-first.
//  Couvre uniquement la zone basse de la carte (heightRatio).
//  Le gradient s'adapte automatiquement à la luminosité du texte.
//
//  Logique :
//  - textColor clair (luminance > 0.45) → gradient sombre (black)
//  - textColor sombre (luminance ≤ 0.45) → gradient clair (white)
//

import SwiftUI
import UIKit

// MARK: - AdaptiveCardTextOverlay

/// Overlay gradient adaptatif concentré sur le bas d'une carte image.
///
/// Usage :
/// ```swift
/// .overlay {
///     AdaptiveCardTextOverlay(textColor: palette.primary)
/// }
/// ```
struct AdaptiveCardTextOverlay: View {

    /// Couleur principale du texte — détermine la teinte du gradient.
    var textColor: Color

    /// Proportion de la hauteur totale couverte par l'overlay (0.0–1.0).
    var heightRatio: CGFloat = 0.35

    /// Opacité maximale du gradient en bas de carte.
    var maxOpacity: CGFloat = 0.45

    var body: some View {
        LinearGradient(stops: gradientStops, startPoint: .top, endPoint: .bottom)
            .blur(radius: 2.5, opaque: false)
            .allowsHitTesting(false)
    }

    // MARK: - Gradient

    private var gradientStops: [Gradient.Stop] {
        let zoneStart   = 1.0 - heightRatio    // début de la zone visible (ex: 0.65 pour 35%)
        let color       = gradientBaseColor

        return [
            .init(color: .clear,                    location: 0.00),
            .init(color: .clear,                    location: zoneStart),
            .init(color: color.opacity(0.08),       location: zoneStart + heightRatio * 0.45),
            .init(color: color.opacity(0.22),       location: zoneStart + heightRatio * 0.72),
            .init(color: color.opacity(maxOpacity), location: 1.00),
        ]
    }

    /// Teinte du gradient : sombre si le texte est clair, clair si le texte est sombre.
    private var gradientBaseColor: Color {
        isTextColorLight ? .black : .white
    }

    // MARK: - Luminance helper

    /// `true` si la couleur est perceptivement claire.
    /// Basé sur la luminance relative sRGB (ITU-R BT.709).
    private var isTextColorLight: Bool {
        let ui = UIColor(textColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return true     // fallback : texte blanc → gradient sombre
        }
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.45
    }
}

// MARK: - Preview

#Preview("AdaptiveCardTextOverlay") {
    VStack(spacing: 20) {
        // Texte clair → gradient sombre
        ZStack {
            LinearGradient(
                colors: [.indigo, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            AdaptiveCardTextOverlay(textColor: .white)
            Text("Texte clair → gradient sombre")
                .foregroundStyle(.white)
                .font(.headline)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding()
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))

        // Texte sombre → gradient clair
        ZStack {
            LinearGradient(
                colors: [.yellow, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            AdaptiveCardTextOverlay(textColor: .black)
            Text("Texte sombre → gradient clair")
                .foregroundStyle(.black)
                .font(.headline)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding()
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
    }
    .padding()
}
