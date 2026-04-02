//
//  BalibuButtonStyle.swift
//  Balibu
//
//  Style premium minimal pour les boutons.
//

import SwiftUI

struct BalibuPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium, design: .default))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isEnabled ? Color.black : Color.gray.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

typealias BalibuButtonStyle = BalibuPrimaryButtonStyle

struct BalibuSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium, design: .default))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

#Preview {
    VStack(spacing: 16) {
        Button("Rechercher des similaires") {}
            .buttonStyle(BalibuPrimaryButtonStyle())
        Button("Annuler") {}
            .buttonStyle(BalibuSecondaryButtonStyle())
    }
    .padding()
}
