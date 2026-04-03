//
//  ResultsStickyBar.swift
//
//  Bannière collante : retour · miniature centrée · infos (sans titre « Results »).
//

import SwiftUI

struct ResultsStickyBar: View {
    let thumbnail: UIImage?
    let onInfoTap: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let thumbSize: CGFloat = 40

    var body: some View {
        HStack(spacing: DesignTokens.spacingS) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Retour"))

            Spacer(minLength: 0)

            thumbnailView
                .frame(width: thumbSize, height: thumbSize)
                .clipShape(RoundedRectangle(cornerRadius: thumbSize * 0.22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: thumbSize * 0.22, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            Button {
                onInfoTap()
            } label: {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Détails de l’analyse"))
        }
        .padding(.horizontal, DesignTokens.spacingXS)
        .padding(.vertical, DesignTokens.spacingXXS)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let ui = thumbnail {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: thumbSize * 0.22, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemFill))
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(Color.secondary)
                }
        }
    }
}
