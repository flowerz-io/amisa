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
        static let cardHeight: CGFloat     = 236
        static let cornerRadius: CGFloat   = 19
        static let logoHeight: CGFloat     = 17
        static let logoMaxWidth: CGFloat   = 70
        static let topEdgePadding: CGFloat = 12
        /// ~90 % de la taille « callout » pour le prix.
        static let priceFontSize: CGFloat  = 15.3
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

    /// Toujours une valeur (`listing.size`, sinon `displaySize`, sinon `NS`).
    private var displaySizeLabel: String {
        let rawSize = (listing.size ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawSize.isEmpty { return rawSize }
        if let ds = listing.displaySize, !ds.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ds.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "NS"
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
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
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
        let maxOp = min(0.12 + palette.bottomLuminance * 0.40, 0.48)

        return LinearGradient(
            stops: [
                .init(color: .clear,                   location: 0.00),
                .init(color: .clear,                   location: 0.55),
                .init(color: .black.opacity(0.18),     location: 0.72),
                .init(color: .black.opacity(maxOp),    location: 1.00),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    // MARK: - Bloc texte (marque + titre + prix) ancré en bas

    private var textBlock: some View {
        ZStack(alignment: .bottomTrailing) {
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

                LiquidGlassPill(text: displaySizeLabel, textColor: adaptivePillTextColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(listing.formattedPrice)
                .font(.system(size: Layout.priceFontSize, weight: .bold))
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.28), radius: 2, x: 0, y: 1)
        }
        // Paddings internes divisés par 2 (12→6, 9→5)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { TextReadabilityPlate() }
        // Paddings externes divisés par 2 (12→6)
        .padding(.bottom, 6)
        .padding(.horizontal, 6)
    }

    // MARK: - Provider badge

    private var providerBadge: some View {
        ProviderLogoView(
            source: listing.source,
            fallbackLabel: listing.sourceDisplayLabel,
            logoHeight: Layout.logoHeight,
            logoMaxWidth: Layout.logoMaxWidth
        )
        .opacity(0.92)
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
