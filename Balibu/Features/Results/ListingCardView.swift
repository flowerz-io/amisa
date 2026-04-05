//
//  ListingCardView.swift
//  Balibu
//
//  Carte annonce grille (2 colonnes) — style minimal type Apple.
//

import SwiftUI
import UIKit

/// Carte listing : image, badge source, marque, titre, méta (taille · état), prix. Toute la carte ouvre l’URL.
struct ListingCardView: View {
    let listing: MarketplaceListing

    private enum Layout {
        /// Hauteur fixe zone image (identique pour toutes les cartes).
        static let imageHeight: CGFloat = 190
        /// Hauteur fixe bloc texte (identique pour toutes les cartes).
        static let textBlockHeight: CGFloat = 92
        /// Rayon de carte explicite.
        static let cardCornerRadius: CGFloat = DesignTokens.radiusM
        /// Taille visuelle logo provider (x2 vs version précédente).
        static let logoHeight: CGFloat = 28
        static let logoMaxWidth: CGFloat = 120
        static let logoPadding: CGFloat = 8
    }

    var body: some View {
        Button {
            openListing()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                imageSection

                VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
                    if let brand = displayBrand {
                        Text(brand)
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Text(listing.title)
                        .font(DesignTokens.body)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let meta = metaLine {
                        Text(meta)
                            .font(DesignTokens.caption)
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }

                    Text(listing.formattedPrice)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(DesignTokens.spacingS)
                .frame(height: Layout.textBlockHeight, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                    .strokeBorder(DesignTokens.cardStroke, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
        .opacity(listing.listingURL == nil ? 0.55 : 1)
        .disabled(listing.listingURL == nil)
    }

    private var displayBrand: String? {
        let b = listing.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return b.isEmpty ? nil : b
    }

    private var imageSection: some View {
        ZStack(alignment: .topTrailing) {
            ListingCardImageView(imageURL: listing.thumbnailURL ?? listing.imageURL)

            ProviderLogoOverlay(
                source: listing.source,
                fallbackLabel: listing.sourceDisplayLabel,
                logoHeight: Layout.logoHeight,
                logoMaxWidth: Layout.logoMaxWidth
            )
            .padding(Layout.logoPadding)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Layout.imageHeight)
        .clipped()
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: Layout.cardCornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Layout.cardCornerRadius,
                style: .continuous
            )
        )
    }

    private var metaLine: String? {
        let s = listing.size?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let c = listing.condition?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasS = !s.isEmpty
        let hasC = !c.isEmpty
        if hasS, hasC {
            return "\(s) · \(c)"
        }
        if hasS {
            return s
        }
        if hasC {
            return c
        }
        return nil
    }

    private func openListing() {
        guard let url = listing.listingURL else { return }
        UIApplication.shared.open(url)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if let b = displayBrand {
            parts.append(b)
        }
        parts.append(contentsOf: [listing.title, listing.formattedPrice, listing.sourceDisplayLabel])
        if let meta = metaLine {
            parts.append(meta)
        }
        return parts.joined(separator: ", ")
    }
}

private struct ListingCardImageView: View {
    let imageURL: URL?

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .clipped()
            case .failure:
                placeholder
            case .empty:
                placeholder.overlay { ProgressView() }
            @unknown default:
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .clipped()
    }

    private var placeholder: some View {
        Rectangle()
            .fill(DesignTokens.imagePlaceholderFill)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(Color.secondary)
            }
    }
}

private struct ProviderLogoOverlay: View {
    let source: String
    let fallbackLabel: String
    let logoHeight: CGFloat
    let logoMaxWidth: CGFloat

    var body: some View {
        if let uiImage = resolvedLogo {
            Image(uiImage: uiImage)
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: logoMaxWidth, height: logoHeight, alignment: .center)
                .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)
                .accessibilityLabel(fallbackLabel)
        } else {
            Text(fallbackLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .accessibilityLabel(fallbackLabel)
        }
    }

    private var resolvedLogo: UIImage? {
        guard let assetName = MarketplaceSource.providerLogoAssetName(for: source) else {
            return nil
        }
        guard let image = UIImage(named: assetName) else {
            return nil
        }
        guard image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        return image
    }
}

#Preview("Listing card") {
    ListingCardView(listing: MarketplaceListing.mockListings[0])
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
