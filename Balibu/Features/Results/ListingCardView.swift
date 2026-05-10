//
//  ListingCardView.swift
//  Balibu
//
//  Carte annonce marketplace — direction éditoriale premium / image-first.
//
//  RÈGLE DE LAYOUT STRICTE :
//  Le container fixe impose toutes les dimensions.
//  L'image est en .overlay{} → elle ne peut JAMAIS agrandir la carte.
//
//  Anatomie :
//  ┌─────────────────────────────────┐
//  │                   [logo badge]  │  ← ProviderLogoView (.topTrailing)
//  │                                 │
//  │        IMAGE (scaledToFill)     │  ← overlay, jamais plus grande que le container
//  │                                 │
//  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  ← gradient overlay (clear → noir)
//  │ [Taille]  [État]                │  ← deux pills séparées
//  │ Marque                          │
//  │ Titre du produit       Prix →   │
//  └─────────────────────────────────┘
//

import SwiftUI

// MARK: - ListingCardView

/// Carte listing grille 2-colonnes — surface immersive, image plein format.
struct ListingCardView: View {
    let listing: MarketplaceListing

    @State private var palette: ListingColorPalette = .fallback

    // MARK: Layout constants

    private enum Layout {
        /// Hauteur fixe — IMPOSÉE par le container, jamais par l'image.
        static let cardHeight: CGFloat     = 236
        /// Radius réduit de 20% par rapport à la version précédente (26 → 21).
        static let cornerRadius: CGFloat   = 21
        static let logoHeight: CGFloat     = 20
        static let logoMaxWidth: CGFloat   = 82
        static let contentPadding: CGFloat = 11
    }

    // MARK: Body

    var body: some View {
        Button { openListing() } label: {
            cardContainer
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
                .overlay(cardBorder)
                .shadow(color: .black.opacity(0.13), radius: 10, x: 0, y: 4)
                .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(listing.listingURL == nil)
        .opacity(listing.listingURL == nil ? 0.55 : 1)
        .accessibilityLabel(accessibilityDescription)
        .task(id: listing.thumbnailURL?.absoluteString ?? listing.imageURL?.absoluteString) {
            palette = await ImagePaletteExtractor.shared.palette(
                for: listing.thumbnailURL ?? listing.imageURL
            )
        }
    }

    // MARK: - Card container (source de vérité des dimensions)

    /// Container fixe. L'image est en overlay et ne peut jamais agrandir ce container.
    private var cardContainer: some View {
        Color(uiColor: .systemGray5)              // placeholder visible sans image
            .frame(maxWidth: .infinity)
            .frame(height: Layout.cardHeight)
            // ── Couche 1 : image en arrière-plan ────────────────────────────
            .overlay { cardImageLayer }
            // ── Couche 2 : overlay adaptatif de lisibilité ──────────────────
            .overlay { AdaptiveCardTextOverlay(textColor: palette.primary) }
            // ── Couche 3 : contenu texte + pills, ancré en bas ──────────────
            .overlay(alignment: .bottom) { bottomContent }
            // ── Couche 4 : badge marketplace, ancré en haut à droite ────────
            .overlay(alignment: .topTrailing) { providerBadge }
    }

    // MARK: - Image layer

    /// L'image est proposée exactement la taille du container via overlay.
    /// .frame(maxWidth:maxHeight:) + .clipped() garantissent qu'elle ne déborde jamais.
    private var cardImageLayer: some View {
        AsyncImage(url: listing.thumbnailURL ?? listing.imageURL) { phase in
            switch phase {
            case .success(let img):
                img
                    .resizable()
                    .scaledToFill()
            case .failure:
                Color.clear
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.35))
                    }
            case .empty:
                Color.clear
                    .overlay { ProgressView().tint(.white.opacity(0.5)) }
            @unknown default:
                Color.clear
            }
        }
        // Critique : maxWidth/maxHeight fill l'overlay, clipped() absorbe le débordement scaledToFill
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Bottom content

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            metaPills

            if !listing.displayBrand.isEmpty, listing.displayBrand != "No brand" {
                Text(listing.displayBrand)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
            }

            HStack(alignment: .bottom, spacing: 6) {
                Text(listing.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(listing.formattedPrice)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Layout.contentPadding)
    }

    // MARK: - Pills (taille ET condition séparées — jamais fusionnées)

    @ViewBuilder
    private var metaPills: some View {
        // Taille et condition sont deux pills distinctes, affichées indépendamment.
        let hasMeta = listing.displaySize != nil || listing.displayCondition != nil
        if hasMeta {
            HStack(spacing: 5) {
                if let size = listing.displaySize, !size.isEmpty {
                    MetaPill(text: size)
                }
                if let condition = listing.displayCondition, !condition.isEmpty {
                    MetaPill(text: condition)
                }
            }
        }
    }

    // MARK: - Provider badge

    private var providerBadge: some View {
        ProviderLogoView(
            source: listing.source,
            fallbackLabel: listing.sourceDisplayLabel,
            logoHeight: Layout.logoHeight,
            logoMaxWidth: Layout.logoMaxWidth
        )
        .padding(8)
    }

    // MARK: - Border

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .strokeBorder(.black.opacity(0.09), lineWidth: 0.5)
    }

    // MARK: - Helpers

    private func openListing() {
        guard let url = listing.listingURL else { return }
        UIApplication.shared.open(url)
    }

    private var accessibilityDescription: String {
        var parts: [String] = [listing.displayBrand, listing.title, listing.formattedPrice, listing.sourceDisplayLabel]
        if let size = listing.displaySize { parts.append(size) }
        if let condition = listing.displayCondition { parts.append(condition) }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - MetaPill

/// Pill glassmorphism pour métadonnée (taille ou condition, jamais les deux).
private struct MetaPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background { Capsule().fill(.ultraThinMaterial) }
            .overlay { Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5) }
    }
}

// MARK: - Preview

#Preview("Grille 2 colonnes") {
    ScrollView {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ],
            spacing: 12
        ) {
            ForEach(MarketplaceListing.mockListings.prefix(6)) { listing in
                ListingCardView(listing: listing)
            }
        }
        .padding(16)
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
