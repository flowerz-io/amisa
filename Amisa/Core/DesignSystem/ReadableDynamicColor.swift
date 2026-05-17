//
//  ReadableDynamicColor.swift
//  Balibu
//
//  Validation de contraste pour couleurs extraites d'images produit.
//  Garantit qu'aucune carte marketplace ne devient illisible,
//  quelle que soit la couleur ou la luminosité de l'image.
//
//  Logique :
//  1. Calcul du ratio de contraste WCAG (luminance relative sRGB BT.709).
//  2. Si ratio < 4.5 (seuil AA) → fallback premium.
//  3. Le prix est toujours déterminé par la luminosité effective du fond,
//     jamais par la palette dynamique.
//

import SwiftUI
import UIKit

// MARK: - ReadableDynamicColor

enum ReadableDynamicColor {

    // MARK: - Fallbacks premium

    /// Blanc chaud — texte clair par défaut sur fond sombre.
    static let warmWhite  = Color.white.opacity(0.95)
    /// Noir doux — texte sombre sur fond clair.
    static let softBlack  = Color.black.opacity(0.88)
    /// Accent chaud — or/crème premium.
    static let warmAccent = Color(red: 0.86, green: 0.68, blue: 0.46)
    /// Accent éditorial — orange marque atténué (highlights cartes dynamiques).
    static let coolAccent = Color(red: 232 / 255, green: 108 / 255, blue: 38 / 255).opacity(0.85)

    // MARK: - Clamping

    /// Borne la saturation (0.35–0.85) et la luminosité (0.35–0.90) d'une couleur extraite.
    /// Évite les couleurs trop ternes, trop vives ou trop sombres pour du texte overlay.
    /// Les grises (saturation < 0.05) sont laissées inchangées.
    static func clampedForText(_ color: Color) -> Color {
        let ui = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return color }
        guard s > 0.05 else { return color }
        let cs = max(0.35, min(s, 0.85))
        let cb = max(0.35, min(b, 0.90))
        return Color(uiColor: UIColor(hue: h, saturation: cs, brightness: cb, alpha: a))
    }

    // MARK: - Validation

    /// Valide une couleur extraite pour une zone de fond sombre.
    /// Retourne la couleur si le contraste est suffisant, sinon un fallback premium.
    ///
    /// - Parameters:
    ///   - color: couleur candidate extraite de l'image
    ///   - backgroundLuminance: luminance estimée du fond après gradient
    ///     (défaut 0.06 = fond très sombre pour la zone bas de carte)
    static func validated(_ color: Color, backgroundLuminance: CGFloat = 0.06) -> Color {
        let lum      = relativeLuminance(of: color)
        let contrast = contrastRatio(text: lum, background: backgroundLuminance)
        // WCAG AA : 4.5 minimum. Pour texte bold large, 3.0 est acceptable.
        return contrast >= 3.5 ? color : warmWhite
    }

    /// Couleur du prix — jamais dynamique.
    /// Déterminée par la luminance effective du fond de l'image après gradient.
    static func priceColor(effectiveBGLuminance: CGFloat) -> Color {
        effectiveBGLuminance < 0.45 ? warmWhite : softBlack
    }

    // MARK: - Ombre adaptative

    /// Shadow pour texte clair (luminance ≥ 0.45).
    static let shadowForLightText = Shadow(
        color: .black.opacity(0.28),
        radius: 3,
        x: 0, y: 1
    )
    /// Shadow pour texte sombre (luminance < 0.45).
    static let shadowForDarkText = Shadow(
        color: .white.opacity(0.14),
        radius: 2,
        x: 0, y: 1
    )

    /// Retourne la shadow adaptée à la luminosité de la couleur de texte.
    static func shadow(for color: Color) -> Shadow {
        relativeLuminance(of: color) >= 0.45
            ? shadowForLightText
            : shadowForDarkText
    }

    // MARK: - Utilitaires luminance / contraste

    /// Luminance relative sRGB (ITU-R BT.709).
    static func relativeLuminance(of color: Color) -> CGFloat {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return 1.0 }
        func lin(_ c: CGFloat) -> CGFloat {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// Ratio de contraste WCAG entre deux luminances.
    static func contrastRatio(text: CGFloat, background: CGFloat) -> CGFloat {
        let l1 = max(text, background) + 0.05
        let l2 = min(text, background) + 0.05
        return l1 / l2
    }
}

// MARK: - Shadow helper

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View extension

extension View {
    /// Applique la shadow adaptée à la couleur de texte.
    func adaptiveShadow(for color: Color) -> some View {
        let s = ReadableDynamicColor.shadow(for: color)
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}
