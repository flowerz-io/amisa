//
//  AdaptiveCardTextOverlay.swift
//  Balibu
//
//  Overlay gradient adaptatif pour cartes image-first.
//  Remplacé par AdaptiveCardOverlay — ce fichier contient désormais ce composant.
//
//  Logique :
//  - bottomLuminance < 0.35  → image sombre → gradient discret (max ~0.28)
//  - bottomLuminance 0.35–0.65 → image moyenne → gradient standard (max ~0.48)
//  - bottomLuminance > 0.65  → image claire → gradient fort (max ~0.72)
//  - Toujours un dégradé noir (plus universel que blanc)
//  - Blur très léger pour adoucir les bords du gradient
//

import SwiftUI

// MARK: - AdaptiveCardOverlay

/// Overlay gradient adaptatif concentré sur le bas d'une carte image-first.
/// Pilote la lisibilité du texte en s'adaptant à la luminosité de l'image.
struct AdaptiveCardOverlay: View {

    /// Luminance moyenne du bas de l'image (0.0 sombre → 1.0 très clair).
    var bottomLuminance: CGFloat

    /// Part de la hauteur couverte par le gradient (0.0–1.0).
    var heightRatio: CGFloat = 0.35

    // MARK: - Body

    var body: some View {
        LinearGradient(stops: gradientStops, startPoint: .top, endPoint: .bottom)
            .blur(radius: 2.5, opaque: false)
            .allowsHitTesting(false)
    }

    // MARK: - Gradient

    /// Opacité max adaptée à la luminosité : plus l'image est claire, plus on assombrit.
    private var maxOpacity: CGFloat {
        // Plage 0.22 (image sombre) → 0.74 (image très claire), capped à 0.74
        min(0.22 + bottomLuminance * 0.58, 0.74)
    }

    private var gradientStops: [Gradient.Stop] {
        let zoneStart = 1.0 - heightRatio   // 0.65 pour heightRatio = 0.35
        let op        = maxOpacity

        return [
            .init(color: .clear,                    location: 0.00),
            .init(color: .clear,                    location: zoneStart),
            .init(color: .black.opacity(op * 0.18), location: zoneStart + heightRatio * 0.45),
            .init(color: .black.opacity(op * 0.52), location: zoneStart + heightRatio * 0.72),
            .init(color: .black.opacity(op),        location: 1.00),
        ]
    }
}

// MARK: - Preview

#Preview("AdaptiveCardOverlay") {
    VStack(spacing: 16) {
        ForEach(
            [(0.1, "Image sombre"), (0.5, "Image moyenne"), (0.9, "Image très claire")],
            id: \.1
        ) { (lum, label) in
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(Color(white: lum))
                AdaptiveCardOverlay(bottomLuminance: lum)
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .adaptiveShadow(for: .white)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        }
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
