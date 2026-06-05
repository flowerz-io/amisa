//
//  ListingCardView.swift
//  Balibu
//
//  Composant unique réutilisable pour les cartes marketplace.
//  Utilisé dans : Home/Découverte, Résultats d'analyse.
//
//  RÈGLE DE LAYOUT STRICTE :
//  Le container fixe impose toutes les dimensions.
//  L'image est en .overlay{} → elle ne peut JAMAIS agrandir la carte.
//
//  Anatomie :
//  ┌─────────────────────────────────┐
//  │                     [badge]    │
//  │       IMAGE scaledToFill        │
//  │░░░░░░░ gradient 45% bas ░░░░░░░│
//  │  Marque                         │
//  │  Modèle (pleine largeur)        │
//  │  [pill taille]          prix → │
//  └─────────────────────────────────┘
//

import SwiftUI

// MARK: - MarketplaceVisualCard

/// Carte annonce marketplace premium — image plein format, texte overlay, dimensions fixes.
struct MarketplaceVisualCard: View {
    let listing: MarketplaceListing

    @State private var palette: ListingColorPalette = .fallback

    // MARK: Layout

    private enum Layout {
        static let cardHeight: CGFloat     = AmisaChrome.productCardHeight
        static let cornerRadius: CGFloat   = AmisaChrome.productCardRadius
        static let logoHeight: CGFloat     = 14
        static let logoMaxWidth: CGFloat   = 56
        static let topEdgePadding: CGFloat = 10
        static let contentPaddingH: CGFloat = 10
        static let contentPaddingV: CGFloat = 8
        static let priceFontSize: CGFloat  = 16
    }

    // MARK: - Couleurs validées

    private var titleColor: Color {
        ReadableDynamicColor.validated(
            ReadableDynamicColor.clampedForText(palette.primary),
            backgroundLuminance: effectiveBGLuminance
        )
    }

    private var brandColor: Color {
        ReadableDynamicColor.validated(
            ReadableDynamicColor.clampedForText(palette.secondary),
            backgroundLuminance: effectiveBGLuminance
        )
    }

    private var effectiveBGLuminance: CGFloat {
        let maxOp = min(0.12 + palette.bottomLuminance * 0.40, 0.48)
        return palette.bottomLuminance * (1.0 - maxOp)
    }

    private var showBrand: Bool {
        !listing.displayBrand.isEmpty && listing.displayBrand != "No brand"
    }

    private var displaySizeLabel: String {
        listing.cardSizeLabel
    }

    /// Couleur du texte de la pill taille, adaptée à la luminosité de l'image.
    /// - fond clair (luminance > 0.55) → noir opacity 0.85
    /// - fond sombre               → blanc opacity 0.95
    private var adaptivePillTextColor: Color {
        palette.bottomLuminance > 0.55
            ? .black.opacity(0.85)
            : .white.opacity(0.95)
    }

    // MARK: - Body

    var body: some View {
        Button { openListing() } label: {
            cardContainer
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
                .overlay(cardBorder)
                .shadow(
                    color: AmisaChrome.productCardShadow,
                    radius: AmisaChrome.productCardShadowRadius,
                    x: 0,
                    y: AmisaChrome.productCardShadowY
                )
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
        .onAppear {
            print("[RESULT_CARD] title:", listing.title, "size:", listing.size ?? "nil")
        }
    }

    // MARK: - Card container

    private var cardContainer: some View {
        Color(uiColor: .systemGray5)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.cardHeight)
            // Couche 1 — image
            .overlay { cardImageLayer }
            // Couche 2 — gradient de lisibilité (45% bas, toujours présent)
            .overlay { bottomGradient }
            // Couche 3 — bloc texte ancré en bas (marque, modèle, pill taille, prix)
            .overlay(alignment: .bottom) { textBlock }
            // Couche 4 — badge marketplace top-right
            .overlay(alignment: .topTrailing) { providerBadge }
            // Couche 5 — score similarité discret (analyse image)
            .overlay(alignment: .topLeading) { visualSimilarityBadge }
    }

    @ViewBuilder
    private var visualSimilarityBadge: some View {
        if let s = listing.visualSimilarityScore, s >= 85 {
            Text("\(Int(round(s)))% similaire")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.black.opacity(0.42), in: Capsule())
                .padding(.top, Layout.topEdgePadding)
                .padding(.leading, Layout.topEdgePadding)
        }
    }

    // MARK: - Image (légère harmonisation)

    private var cardImageLayer: some View {
        AsyncImage(url: listing.thumbnailURL ?? listing.imageURL) { phase in
            switch phase {
            case .success(let img):
                img
                    .resizable()
                    .scaledToFill()
                    .saturation(0.94)
                    .contrast(1.03)
            case .failure:
                Color.clear.overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.35))
                }
            case .empty:
                Color.clear.overlay { ProgressView().tint(.white.opacity(0.5)) }
            @unknown default:
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Gradient (45% inférieurs, toujours présent)

    /// Gradient concentré sur les 45% inférieurs de la carte.
    /// Toujours noir pour garantir la lisibilité du texte blanc.
    /// Opacité max adaptée : 0.12 (image sombre) → 0.48 (image très claire).
    private var bottomGradient: some View {
        let maxOp = min(0.16 + palette.bottomLuminance * 0.42, 0.52)

        return LinearGradient(
            stops: [
                .init(color: .clear,                   location: 0.00),
                .init(color: .clear,                   location: 0.50),
                .init(color: .black.opacity(0.22),     location: 0.70),
                .init(color: .black.opacity(maxOp),    location: 1.00),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    // MARK: - Bloc texte (marque + titre + prix) ancré en bas

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            if showBrand {
                Text(listing.displayBrand)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(brandColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shadow(color: .black.opacity(0.28), radius: 2, x: 0, y: 1)
            }

            Text(listing.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(titleColor)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shadow(color: .black.opacity(0.28), radius: 2, x: 0, y: 1)

            HStack(alignment: .center, spacing: 8) {
                LiquidGlassPill(text: displaySizeLabel, textColor: adaptivePillTextColor)

                Spacer(minLength: 4)

                Text(listing.formattedPrice)
                    .font(.system(size: Layout.priceFontSize, weight: .bold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .shadow(color: .black.opacity(0.32), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.horizontal, Layout.contentPaddingH)
        .padding(.vertical, Layout.contentPaddingV)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { TextReadabilityPlate() }
        .padding(.bottom, Layout.contentPaddingV)
        .padding(.horizontal, Layout.contentPaddingH)
    }

    // MARK: - Provider badge

    private var providerBadge: some View {
        ProviderLogoView(
            source: listing.source,
            fallbackLabel: listing.sourceDisplayLabel,
            logoHeight: Layout.logoHeight,
            logoMaxWidth: Layout.logoMaxWidth
        )
        .opacity(0.88)
        .scaleEffect(0.92, anchor: .topTrailing)
        .padding(.top, Layout.topEdgePadding)
        .padding(.trailing, Layout.topEdgePadding)
    }

    // MARK: - Border

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
    }

    // MARK: - Helpers

    private func openListing() {
        guard let url = listing.listingURL else { return }
        UIApplication.shared.open(url)
    }

    private var accessibilityDescription: String {
        var parts: [String] = [listing.displayBrand, listing.title, listing.formattedPrice, listing.sourceDisplayLabel]
        parts.append(displaySizeLabel)
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - Backward compatibility

typealias ListingCardView = MarketplaceVisualCard

// MARK: - TextReadabilityPlate

/// Micro-fond flou derrière le bloc marque/titre/prix.
private struct TextReadabilityPlate: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.black.opacity(0.14))
            .blur(radius: 8)
    }
}

// MARK: - Preview

#Preview("MarketplaceVisualCard — grille") {
    ScrollView {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ],
            spacing: 12
        ) {
            ForEach(MarketplaceListing.mockListings.prefix(6)) { listing in
                MarketplaceVisualCard(listing: listing)
            }
        }
        .padding(16)
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
