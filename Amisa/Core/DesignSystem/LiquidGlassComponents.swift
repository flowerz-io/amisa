import SwiftUI

// MARK: - LiquidGlassPill

/// Pill réutilisable à effet Liquid Glass (matériau ultraThin, highlight, contour, ombre douce).
/// Utilisé pour : pill taille dans les cartes marketplace, pills similaires dans les résultats.
struct LiquidGlassPill: View {
    let text: String
    var textColor: Color = .white.opacity(0.95)

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background { pillBackground }
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    private var pillBackground: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)

            // Contour interne clair (plus fort en light, plus discret en dark)
            Capsule()
                .strokeBorder(
                    .white.opacity(colorScheme == .dark ? 0.22 : 0.35),
                    lineWidth: 1
                )

            // Highlight blanc en haut-gauche
            LinearGradient(
                colors: [.white.opacity(0.35), .white.opacity(0.05), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(Capsule())
        }
        // Contour externe sombre très subtil
        .overlay(
            Capsule()
                .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - LiquidGlassTabBarBackground

/// Fond Liquid Glass pour les capsules de la tab bar custom.
/// Remplace tout fond opaque : ultraThinMaterial + highlight + contour + ombre flottante.
struct LiquidGlassTabBarBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)

            // Contour interne clair
            Capsule()
                .strokeBorder(
                    .white.opacity(colorScheme == .dark ? 0.22 : 0.35),
                    lineWidth: 1
                )

            // Highlight blanc en haut-gauche (effet verre)
            LinearGradient(
                colors: [.white.opacity(0.22), .white.opacity(0.04), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(Capsule())
        }
        // Contour externe sombre très subtil
        .overlay(
            Capsule()
                .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
    }
}

// MARK: - ClearLiquidGlassCircleButtonStyle

/// Bouton circulaire type Liquid Glass clair (matériau + highlight + contour lumineux).
struct ClearLiquidGlassCircleButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    /// Diamètre du bouton (défaut 62 pt ; ex. ~44 pt pour un chrome résultats plus discret).
    var diameter: CGFloat = 62

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: diameter, height: diameter)
            .background {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradientHighlightColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: strokeColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 14, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }

    private var gradientHighlightColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.white.opacity(0.14),
                Color.white.opacity(0.06),
                Color.white.opacity(0.02),
            ]
        }
        return [
            Color.white.opacity(0.42),
            Color.white.opacity(0.16),
            Color.white.opacity(0.05),
        ]
    }

    private var strokeColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.white.opacity(0.35),
                Color.white.opacity(0.12),
                Color.black.opacity(0.35),
            ]
        }
        return [
            Color.white.opacity(0.85),
            Color.white.opacity(0.25),
            Color.black.opacity(0.08),
        ]
    }
}
