//
//  ResultsStickyBar.swift
//
//  Bannière collante : retour · miniature (tap = plein écran) · favori · infos.
//

import SwiftUI

struct ResultsStickyBar: View {
    let thumbnail: UIImage?
    let isFavorite: Bool
    let onFavoriteTap: () -> Void
    let onImageTap: () -> Void
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

            Button {
                onImageTap()
            } label: {
                thumbnailView
                    .frame(width: thumbSize, height: thumbSize)
                    .clipShape(RoundedRectangle(cornerRadius: thumbSize * 0.22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: thumbSize * 0.22, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Agrandir l’image"))

            Spacer(minLength: 0)

            Button {
                onFavoriteTap()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.body)
                    .foregroundStyle(isFavorite ? Color.red : Color.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Favori"))

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
