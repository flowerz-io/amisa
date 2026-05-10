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
//  │ [Taille]            [badge]    │  ← pill taille + badge alignés à top:12
//  │                                 │
//  │       IMAGE scaledToFill        │
//  │                                 │
//  │░░░░░░░ gradient 45% bas ░░░░░░░│
//  │  ╔══ TextReadabilityPlate ════╗  │
//  │  ║ Marque (caption medium)   ║  │
//  │  ║ Titre semibold   Prix →   ║  │
//  │  ╚═══════════════════════════╝  │
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
        /// Padding uniforme pour pill taille ET badge : même top garantit l'alignement.
        static let topEdgePadding: CGFloat = 12
        static let contentPadding: CGFloat = 12
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
            backgroundLuminance: effectiveBGLuminance + 0.04
        )
    }

    private var priceColor: Color {
        ReadableDynamicColor.priceColor(effectiveBGLuminance: effectiveBGLuminance)
    }

    private var effectiveBGLuminance: CGFloat {
        let maxOp = min(0.12 + palette.bottomLuminance * 0.40, 0.48)
        return palette.bottomLuminance * (1.0 - maxOp)
    }

    private var showBrand: Bool {
        !listing.displayBrand.isEmpty && listing.displayBrand != "No brand"
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
            // Couche 3 — bloc texte ancré en bas
            .overlay(alignment: .bottom) { textBlock }
            // Couche 4 — pill taille top-left (même niveau que badge)
            .overlay(alignment: .topLeading) { sizePill }
            // Couche 5 — badge marketplace top-right (même niveau que pill)
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
        VStack(alignment: .leading, spacing: 2) {
            if showBrand {
                Text(listing.displayBrand)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(brandColor.opacity(0.72))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.28), radius: 2, x: 0, y: 1)
            }

            HStack(alignment: .bottom, spacing: 6) {
                Text(listing.title)
                    // Réduit de ~12% vs .headline (17pt → 15pt), garde le côté éditorial
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shadow(color: .black.opacity(0.28), radius: 2, x: 0, y: 1)

                Text(listing.formattedPrice)
                    .font(.callout.bold())
                    .foregroundStyle(priceColor)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.28), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.horizontal, Layout.contentPadding)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { TextReadabilityPlate() }
        .padding(.bottom, Layout.contentPadding)
        .padding(.horizontal, Layout.contentPadding)
    }

    // MARK: - Pill taille uniquement (état supprimé)

    /// N'affiche QUE la taille. L'état (condition) n'est plus affiché sur les cartes.
    @ViewBuilder
    private var sizePill: some View {
        if let size = listing.displaySize, !size.isEmpty {
            SizePill(text: size)
                .padding(.top, Layout.topEdgePadding)
                .padding(.leading, Layout.topEdgePadding)
        }
    }

    // MARK: - Provider badge (aligné verticalement avec la pill taille)

    private var providerBadge: some View {
        ProviderLogoView(
            source: listing.source,
            fallbackLabel: listing.sourceDisplayLabel,
            logoHeight: Layout.logoHeight,
            logoMaxWidth: Layout.logoMaxWidth
        )
        .opacity(0.92)
        // top et trailing identiques à topEdgePadding → alignement horizontal avec la pill
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
        if let size = listing.displaySize { parts.append(size) }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - Backward compatibility

typealias ListingCardView = MarketplaceVisualCard

// MARK: - SizePill

/// Pill taille uniquement — liquid glass compact.
private struct SizePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background { Capsule().fill(.ultraThinMaterial) }
            .overlay { Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.14), radius: 2, x: 0, y: 1)
    }
}

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
