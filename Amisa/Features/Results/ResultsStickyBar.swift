//
//  ResultsStickyBar.swift
//
//  Bannière collante : retour · miniature (si recherche image) · favori.
//

import SwiftUI

struct ResultsStickyBar: View {
    /// Miniature : uniquement si une image source existe.
    let thumbnail: UIImage?
    let isFavorite: Bool
    let onFavoriteTap: () -> Void
    let onThumbnailTap: (() -> Void)?

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

            if thumbnail != nil, let onThumbnailTap {
                Button(action: onThumbnailTap) {
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
            }

            Spacer(minLength: 0)

            Button {
                onFavoriteTap()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.body)
                    .foregroundStyle(isFavorite ? Color.accentColor : Color.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Favori"))
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
            EmptyView()
        }
    }
}
