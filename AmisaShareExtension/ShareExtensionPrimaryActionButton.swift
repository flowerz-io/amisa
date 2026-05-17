//
//  ShareExtensionPrimaryActionButton.swift
//  BalibuShareExtension
//
//  Même intention que `PrimaryActionButton` (app native).
//

import SwiftUI
import UIKit

struct ShareExtensionPrimaryActionButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isDisabled)
    }
}

/// Surface blanche / texte noir — lisible sur fond sombre ou très contrasté (écran crop).
struct ShareExtensionLightChromePrimaryButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }
}

/// Bouton fermer Review — Liquid Glass clair, au-dessus du contenu.
struct ShareExtensionLiquidGlassDismissButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 58, height: 58)
                .background {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.42),
                                        .white.opacity(0.14),
                                        .white.opacity(0.04),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.9),
                                        .white.opacity(0.28),
                                        .black.opacity(0.08),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                }
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Fermer"))
    }
}

/// Bouton principal Review — halo **hors** du `clipShape`, animation uniquement sur `rotation`.
struct ShareExtensionAnalyzeChromeButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var rotation: Double = 0

    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    private var sparkleSymbolName: String {
        UIImage(systemName: "sparkle.magnifyingglass") != nil
            ? "sparkle.magnifyingglass"
            : "magnifyingglass"
    }

    private var glowGradient: AngularGradient {
        AngularGradient(
            colors: [
                ShareExtensionBrandColors.primaryRed.opacity(0.22),
                ShareExtensionBrandColors.secondaryOrange.opacity(0.88),
                ShareExtensionBrandColors.primaryRed.opacity(0.92),
                ShareExtensionBrandColors.secondaryOrange.opacity(0.55),
                ShareExtensionBrandColors.primaryRed.opacity(0.22),
            ],
            center: .center,
            angle: .degrees(rotation)
        )
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))

                Image(systemName: sparkleSymbolName)
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.96 : 1))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(glowGradient, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(glowGradient, lineWidth: 6)
                .blur(radius: 6)
                .opacity(colorScheme == .dark ? 0.32 : 0.24)
                .padding(-8)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .compositingGroup()
        .shadow(
            color: Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.18),
            radius: 8,
            x: 0,
            y: 4
        )
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .onAppear {
            guard rotation == 0 else { return }
            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
