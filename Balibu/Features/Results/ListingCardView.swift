//
//  ListingCardView.swift
//  Balibu
//
//  Carte annonce grille (2 colonnes) — style minimal type Apple.
//

import SwiftUI

/// Carte listing : image, badge source, marque, titre, méta (taille • état), prix. Toute la carte ouvre l’URL.
struct ListingCardView: View {
    let listing: MarketplaceListing

    /// Ratio portrait produit (largeur : hauteur)
    private static let imageAspectRatio: CGFloat = 3.0 / 4.0

    /// Hauteur minimale du bloc texte pour aligner les cartes en grille
    private static let textBlockMinHeight: CGFloat = 92

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
                .frame(maxWidth: .infinity, minHeight: Self.textBlockMinHeight, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous)
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
            listingImage

            Text(listing.source)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(8)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(Self.imageAspectRatio, contentMode: .fit)
        .clipped()
    }

    @ViewBuilder
    private var listingImage: some View {
        AsyncImage(url: listing.thumbnailURL ?? listing.imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Rectangle()
                    .fill(DesignTokens.imagePlaceholderFill)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(Color.secondary)
                    }
            case .empty:
                Rectangle()
                    .fill(DesignTokens.imagePlaceholderFill)
                    .overlay { ProgressView() }
            @unknown default:
                Rectangle()
                    .fill(DesignTokens.imagePlaceholderFill)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var metaLine: String? {
        let s = listing.size?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let c = listing.condition?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasS = !s.isEmpty
        let hasC = !c.isEmpty
        if hasS, hasC {
            return "\(s) • \(c)"
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
        parts.append(contentsOf: [listing.title, listing.formattedPrice, listing.source])
        if let meta = metaLine {
            parts.append(meta)
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("Listing card") {
    ListingCardView(listing: MarketplaceListing.mockListings[0])
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
