//
//  ShareExtensionResultsTeaserView.swift
//  BalibuShareExtension
//
//  Skeleton premium + résultats réels uniquement (pas de contenu factice).
//

import SwiftUI

// MARK: - Carte compacte

private struct ShareExtensionTeaserCard: View {
    let listing: ShareExtensionTeaserListing

    private let corner: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                teaserImage
                    .frame(maxWidth: .infinity)
                    .frame(height: 112)
                    .clipped()

                Text(listing.displaySource)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))

            Text(listing.formattedPrice)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Text(listing.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: corner + 4, style: .continuous))
    }

    @ViewBuilder
    private var teaserImage: some View {
        let url = listing.thumbnailURL ?? listing.imageURL
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFill()
                case .failure:
                    imagePlaceholder
                case .empty:
                    Color(uiColor: .tertiarySystemFill)
                @unknown default:
                    imagePlaceholder
                }
            }
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        Color(uiColor: .tertiarySystemFill)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
            }
    }
}

// MARK: - Skeleton + shimmer

private struct ShareExtensionPremiumSkeletonCard: View {
    private let corner: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(height: 112)
                    .adaptiveShimmer()

                Capsule()
                    .fill(Color(uiColor: .quaternarySystemFill))
                    .frame(width: 56, height: 22)
                    .padding(8)
                    .adaptiveShimmer()
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(uiColor: .quaternarySystemFill))
                .frame(height: 14)
                .frame(maxWidth: .infinity)
                .adaptiveShimmer()

            HStack(spacing: 8) {
                Capsule()
                    .fill(Color(uiColor: .quaternarySystemFill))
                    .frame(width: 44, height: 22)
                    .adaptiveShimmer()

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(uiColor: .quaternarySystemFill))
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)
                    .adaptiveShimmer()
            }
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: corner + 4, style: .continuous))
    }
}

private struct ShareExtensionWarmupStrip: View {
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(height: 6)
                .frame(maxWidth: pulse ? 220 : 160)
                .opacity(pulse ? 0.55 : 0.85)
                .animation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true), value: pulse)

            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(String(localized: "Préparation de ta recherche…"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Racine

struct ShareExtensionResultsTeaserView: View {
    @ObservedObject var model: ShareFlowModel

    private let gridSpacing: CGFloat = 12
    private let slotCount = 6

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridSpacing),
            GridItem(.flexible(), spacing: gridSpacing),
        ]
    }

    private var visibleAPIListings: [ShareExtensionTeaserListing] {
        Array(model.teaserListingsFromAPI.prefix(slotCount))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch model.extensionGridPhase {
                case .warmingUp:
                    previewHeader
                    ShareExtensionWarmupStrip()
                case .listingGrid:
                    previewHeader

                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(0..<slotCount, id: \.self) { index in
                            gridSlot(at: index)
                        }
                    }
                }

                notificationCopy
                    .padding(.top, 4)

                Color.clear.frame(height: 28)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    @ViewBuilder
    private func gridSlot(at index: Int) -> some View {
        let api = visibleAPIListings
        if index < api.count {
            ShareExtensionTeaserCard(listing: api[index])
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .animation(
                    .spring(response: 0.42, dampingFraction: 0.84)
                        .delay(Double(index) * 0.045),
                    value: api.count
                )
        } else {
            ShareExtensionPremiumSkeletonCard()
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var previewHeader: some View {
        HStack(spacing: 14) {
            if let img = model.loadingPreviewImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Recherche en cours"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(String(localized: "Amisa parcourt les marketplaces pour toi."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var notificationCopy: some View {
        if model.shouldShowPendingNotificationHint {
            Text(String(localized: "Tu recevras une notification quand tout sera prêt."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } else if case .denied = model.notificationScheduleOutcome {
            Text(String(localized: "Notifications désactivées : ouvre Amisa depuis l’accueil pour suivre ta recherche."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } else {
            EmptyView()
        }
    }
}
