//
//  AmisaButtonStyle.swift
//  Balibu
//
//  Style premium minimal pour les boutons.
//

import SwiftUI

struct AmisaPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium, design: .default))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                Group {
                    if isEnabled {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BrandColors.primaryLinearGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BrandColors.primaryDisabled)
                    }
                }
                .opacity(configuration.isPressed && isEnabled ? 0.88 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

typealias AmisaButtonStyle = AmisaPrimaryButtonStyle

struct AmisaSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium, design: .default))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(uiColor: .secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

#Preview {
    VStack(spacing: 16) {
        Button("Rechercher des similaires") {}
            .buttonStyle(AmisaPrimaryButtonStyle())
        Button("Annuler") {}
            .buttonStyle(AmisaSecondaryButtonStyle())
    }
    .padding()
}
