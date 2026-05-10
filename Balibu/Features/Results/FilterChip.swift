//
//  FilterChip.swift
//  Balibu
//
//  Chip compact type Apple pour la barre de filtres.
//

import SwiftUI

struct FilterChip: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingXXS) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                }
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, DesignTokens.spacingS)
            .padding(.vertical, DesignTokens.spacingXXS + 2)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FilterChip(title: "Taille", systemImage: "ruler") {}
        .padding()
}
