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
        /// Hauteur totale carte (strictement fixe).
        static let cardHeight: CGFloat = imageHeight + textBlockHeight
        /// Rayon de carte explicite.
        static let cardCornerRadius: CGFloat = DesignTokens.radiusM
        /// Taille visuelle logo provider (x2 vs version précédente).
        static let logoHeight: CGFloat = 28
        static let logoMaxWidth: CGFloat = 110
        static let logoBottomRowTrailingPadding: CGFloat = 0
    }

    var body: some View {
        Button {
            openListing()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ListingCardImageContainerView(
                    imageURL: listing.thumbnailURL ?? listing.imageURL,
                    source: listing.source,
                    fallbackLabel: listing.sourceDisplayLabel,
                    imageHeight: Layout.imageHeight,
                    logoHeight: Layout.logoHeight,
                    logoMaxWidth: Layout.logoMaxWidth,
                    cardCornerRadius: Layout.cardCornerRadius
                )

                VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
                    Text(listing.displayBrand)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

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

                    HStack(alignment: .center, spacing: DesignTokens.spacingXS) {
                        Text(listing.formattedPrice)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                        Spacer(minLength: DesignTokens.spacingXS)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(DesignTokens.spacingS)
                .frame(height: Layout.textBlockHeight, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Layout.cardHeight, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                    .strokeBorder(DesignTokens.cardStroke, lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
        .opacity(listing.listingURL == nil ? 0.55 : 1)
        .disabled(listing.listingURL == nil)
    }

    private var metaLine: String? {
        let s = listing.displaySize ?? ""
        let c = listing.displayCondition ?? ""
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
        parts.append(listing.displayBrand)
        parts.append(contentsOf: [listing.title, listing.formattedPrice, listing.sourceDisplayLabel])
        if let meta = metaLine {
            parts.append(meta)
        }
        return parts.joined(separator: ", ")
    }
}

private struct ListingCardImageContainerView: View {
    let imageURL: URL?
    let source: String
    let fallbackLabel: String
    let imageHeight: CGFloat
    let logoHeight: CGFloat
    let logoMaxWidth: CGFloat
    let cardCornerRadius: CGFloat

    var body: some View {
        ListingCardImageView(imageURL: imageURL)
        .frame(maxWidth: .infinity)
        .frame(height: imageHeight)
        .clipped()
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: cardCornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: cardCornerRadius,
                style: .continuous
            )
        )
        .overlay(alignment: .topTrailing) {
            ProviderLogoOverlay(
                source: source,
                fallbackLabel: fallbackLabel,
                logoHeight: logoHeight,
                logoMaxWidth: logoMaxWidth
            )
            .padding(.top, 5)
            .padding(.trailing, 5)
        }
    }
}

private struct ListingCardImageView: View {
    let imageURL: URL?

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                        .clipped()
                case .failure:
                    placeholder
                case .empty:
                    placeholder.overlay { ProgressView() }
                @unknown default:
                    placeholder
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .clipped()
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
                .frame(height: logoHeight, alignment: .center)
                .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)
                .accessibilityLabel(fallbackLabel)
                .fixedSize(horizontal: true, vertical: true)
        } else {
            Text(fallbackLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .shadow(color: .black.opacity(0.55), radius: 2, x: 0, y: 1)
                .accessibilityLabel(fallbackLabel)
                .fixedSize(horizontal: true, vertical: true)
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
