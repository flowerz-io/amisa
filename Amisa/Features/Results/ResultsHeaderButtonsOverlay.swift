//
//  ResultsHeaderButtonsOverlay.swift
//  Balibu
//
//  Retour / favori : overlay fixe au-dessus du scroll (safeTop + 10), jamais dans le flux scrollable.
//

import SwiftUI

struct ResultsHeaderButtonsOverlay: View {
    let isFavorite: Bool
    let onBack: () -> Void
    let onFavorite: () -> Void
    let safeTop: CGFloat

    private let circleDiameter: CGFloat = 44

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }
            .buttonStyle(ClearLiquidGlassCircleButtonStyle(diameter: circleDiameter))
            .accessibilityLabel(String(localized: "Retour"))

            Spacer(minLength: 0)

            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isFavorite ? Color.accentColor : Color.primary)
            }
            .buttonStyle(ClearLiquidGlassCircleButtonStyle(diameter: circleDiameter))
            .accessibilityLabel(String(localized: "Favori"))
        }
        .padding(.leading, 14)
        .padding(.trailing, 14)
        .padding(.top, safeTop + 10)
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(true)
    }
}
