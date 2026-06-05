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
            .padding(.horizontal, AmisaChrome.filterPillHorizontalPadding)
            .padding(.vertical, AmisaChrome.filterPillVerticalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FilterChip(title: "Taille", systemImage: "ruler") {}
        .padding()
}
