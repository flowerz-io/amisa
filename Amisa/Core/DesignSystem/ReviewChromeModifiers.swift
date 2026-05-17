//
//  ReviewChromeModifiers.swift
//  Balibu
//
//  Shimmer + bouton Analyser (Review import / alignement Share Extension).
//

import SwiftUI
import UIKit

/// Bouton Analyser : contour animé **dans** le clip, halo **derrière** (non coupé par `clipShape`).
struct AnalyzeGlowChromeButton: View {
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
                BrandColors.primary.opacity(0.25),
                BrandColors.secondary.opacity(0.88),
                BrandColors.primary.opacity(0.92),
                BrandColors.secondary.opacity(0.55),
                BrandColors.primary.opacity(0.25),
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

struct AdaptiveShimmer: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: shimmerColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 260)
                .blendMode(colorScheme == .dark ? .screen : .multiply)
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }

    private var shimmerColors: [Color] {
        if colorScheme == .dark {
            return [
                .white.opacity(0.03),
                .white.opacity(0.12),
                BrandColors.secondaryOrange.opacity(0.10),
                .white.opacity(0.22),
                .white.opacity(0.04),
            ]
        } else {
            return [
                .black.opacity(0.04),
                .black.opacity(0.10),
                BrandColors.secondaryOrange.opacity(0.08),
                .black.opacity(0.16),
                .black.opacity(0.04),
            ]
        }
    }
}

extension View {
    func adaptiveShimmer() -> some View {
        modifier(AdaptiveShimmer())
    }
}
