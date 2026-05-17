//
//  ShareExtensionAdaptiveShimmer.swift
//  BalibuShareExtension
//

import SwiftUI

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
                ShareExtensionBrandColors.secondaryOrange.opacity(0.10),
                .white.opacity(0.22),
                .white.opacity(0.04),
            ]
        } else {
            return [
                .black.opacity(0.04),
                .black.opacity(0.10),
                ShareExtensionBrandColors.secondaryOrange.opacity(0.08),
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
