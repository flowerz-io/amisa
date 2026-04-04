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

    /// Hauteur fixe zone image (identique pour toutes les cartes).
    private static let imageBlockHeight: CGFloat = 190

    /// Hauteur fixe du bloc texte pour garantir des cartes homogènes cross-source
    private static let textBlockHeight: CGFloat = 92

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
                .frame(height: Self.textBlockHeight, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous)
                    .strokeBorder(DesignTokens.cardStroke, lineWidth: 0.5)
            )
            .overlay(alignment: .topTrailing) {
                ProviderBadgeView(source: listing.source, fallbackLabel: listing.sourceDisplayLabel)
                    .padding(8)
            }
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
        ListingCardImageView(imageURL: listing.thumbnailURL ?? listing.imageURL)
        .frame(maxWidth: .infinity)
        .frame(height: Self.imageBlockHeight)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: DesignTokens.radiusM,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: DesignTokens.radiusM,
                style: .continuous
            )
        )
        .clipped()
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

private struct ProviderBadgeView: View {
    let source: String
    let fallbackLabel: String

    private static let badgeHeight: CGFloat = 26
    private static let maxLogoWidth: CGFloat = 72
    private static let logoHeight: CGFloat = 14

    var body: some View {
        let content = resolvedContent
        ZStack {
            if let uiImage = content.logo {
                Image(uiImage: uiImage)
                    .resizable()
                    .renderingMode(.original)
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(width: Self.maxLogoWidth, height: Self.logoHeight, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            } else {
                Text(content.fallbackText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
        }
        .frame(minHeight: Self.badgeHeight)
        .background(
            Color(uiColor: .systemBackground)
                .opacity(0.78),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .accessibilityLabel(content.fallbackText)
    }

    private var resolvedContent: (logo: UIImage?, fallbackText: String) {
        let assetName = MarketplaceSource.providerLogoAssetName(for: source)
        if let assetName,
           let uiImage = UIImage(named: assetName),
           uiImage.size.width > 0,
           uiImage.size.height > 0 {
            print("[PROVIDER_BADGE] source=\(source) asset=\(assetName) fallback=false")
            return (uiImage, fallbackLabel)
        }
        print("[PROVIDER_BADGE] source=\(source) asset=\(assetName ?? "nil") fallback=true")
        return (nil, fallbackLabel)
    }
}

#Preview("Listing card") {
    ListingCardView(listing: MarketplaceListing.mockListings[0])
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
