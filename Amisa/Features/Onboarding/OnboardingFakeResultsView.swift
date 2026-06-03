//
//  OnboardingFakeResultsView.swift
//  Amisa
//

import SwiftUI

private let resultsColumnSpacing: CGFloat = 16
private let resultsGridRowSpacing: CGFloat = 22
private let resultsCardHeight: CGFloat = 188
private let resultsVisibleListingCount = 8
private let resultsLockedListingCount = 6
private let gridTopSpacing: CGFloat = 12
private let resultsHeaderCornerRadius: CGFloat = 20
private let feminineHeaderCropZoom: CGFloat = 1.55

struct OnboardingFakeResultsView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false

    private var look: DemoLook? { model.selectedLook }
    private var listings: [DemoListing] { look?.results ?? [] }

    private let columns = [
        GridItem(.flexible(), spacing: resultsColumnSpacing),
        GridItem(.flexible(), spacing: resultsColumnSpacing),
    ]

    var body: some View {
        Group {
            if let look {
                VStack(spacing: 0) {
                    resultsHeader(look: look)
                        .onboardingStaggeredEntrance(appeared, index: 0)

                    ScrollView(.vertical, showsIndicators: false) {
                        resultsScrollContent
                    }
                    .scrollContentBackground(.hidden)
                }
            } else {
                ProgressView()
                    .tint(OnboardingTheme.accentRed)
            }
        }
        .onboardingScreen()
        .onAppear {
            withAnimation(OnboardingMotion.springPremium.delay(0.06)) {
                appeared = true
            }
        }
    }

    private var resultsScrollContent: some View {
        VStack(spacing: 0) {
            listingsGrid(count: resultsVisibleListingCount, startIndex: 0, lockedStyle: false)
                .padding(.horizontal, 20)
                .padding(.top, gridTopSpacing)

            resultsCTASection
                .padding(.top, resultsGridRowSpacing)
                .padding(.bottom, 32)
        }
    }

    private var resultsCTASection: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    OnboardingTheme.deepBlack.opacity(0),
                    OnboardingTheme.deepBlack.opacity(0.5),
                    OnboardingTheme.deepBlack.opacity(0.92),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 52)

            OnboardingPrimaryButton(
                title: String(localized: "Analyser avec ma propre photo"),
                icon: "camera.fill"
            ) {
                model.next()
            }
            .padding(.horizontal, 24)
        }
        .background(alignment: .bottom) {
            lockedDecorLayer
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var lockedDecorLayer: some View {
        let lockedListings = lockedListingsPreview
        let decorHeight = resultsCardHeight * 3 + resultsGridRowSpacing * 2

        return listingsGrid(listings: lockedListings, lockedStyle: true)
            .padding(.horizontal, 20)
            .frame(height: decorHeight, alignment: .top)
            .mask {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.25),
                        Color.white.opacity(0.55),
                        Color.white,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .offset(y: 56)
    }

    private var lockedListingsPreview: [DemoListing] {
        guard !listings.isEmpty else { return [] }
        return (0..<resultsLockedListingCount).map { index in
            let base = listings[index % listings.count]
            let prefix = look?.id == "feminine" ? "feminine_locked" : "masculine_locked"
            return DemoListing(
                id: "\(prefix)_\(index)",
                imageName: base.imageName,
                brand: base.brand,
                title: base.title,
                price: base.price,
                size: base.size,
                providerLogoName: base.providerLogoName
            )
        }
    }

    private func resultsHeader(look: DemoLook) -> some View {
        resultsHeaderCardContent(look: look)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: resultsHeaderCornerRadius, style: .continuous)
                    .fill(OnboardingTheme.cardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: resultsHeaderCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.06),
                                        Color.clear,
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: resultsHeaderCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: resultsHeaderCornerRadius, style: .continuous)
                    .stroke(OnboardingTheme.cardStroke, lineWidth: 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
    }

    private func listingsGrid(count: Int, startIndex: Int, lockedStyle: Bool) -> some View {
        let slice = Array(listings.dropFirst(startIndex).prefix(count))
        return listingsGrid(listings: slice, lockedStyle: lockedStyle)
    }

    private func listingsGrid(listings: [DemoListing], lockedStyle: Bool) -> some View {
        LazyVGrid(columns: columns, spacing: resultsGridRowSpacing) {
            ForEach(Array(listings.enumerated()), id: \.element.id) { index, listing in
                DemoListingCard(listing: listing)
                    .frame(maxWidth: .infinity)
                    .frame(height: resultsCardHeight)
                    .opacity(lockedStyle ? lockedOpacity(for: index) : 1)
                    .overlay {
                        if lockedStyle {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(OnboardingTheme.deepBlack.opacity(lockedDim(for: index)))
                        }
                    }
                    .onboardingStaggeredEntrance(appeared, index: lockedStyle ? 0 : index + 1, baseDelay: 0.06)
                    .allowsHitTesting(!lockedStyle)
            }
        }
    }

    private func lockedOpacity(for index: Int) -> Double {
        let row = index / 2
        switch row {
        case 0: return 0.5
        case 1: return 0.32
        default: return 0.18
        }
    }

    private func lockedDim(for index: Int) -> Double {
        let row = index / 2
        switch row {
        case 0: return 0.18
        case 1: return 0.28
        default: return 0.4
        }
    }

    private func resultsHeaderCardContent(look: DemoLook) -> some View {
        HStack(spacing: 14) {
            resultsHeaderThumbnail(look: look)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(OnboardingTheme.cardStroke, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("PIÈCE ANALYSÉE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(OnboardingTheme.accentRed.opacity(0.9))
                Text(resultsPieceTitle(for: look))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(OnboardingTheme.offWhite)
                    .lineLimit(1)
                Text("Annonces similaires trouvées")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OnboardingTheme.warmGray)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func resultsHeaderThumbnail(look: DemoLook) -> some View {
        if look.id == "feminine" {
            OnboardingFocusCropThumbnail(
                imageName: look.imageName,
                normalizedFocus: OnboardingAnalysisFocusPresets.female.normalizedRect,
                zoomScale: feminineHeaderCropZoom
            )
        } else {
            OnboardingAssetImageView(imageName: look.imageName)
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func resultsPieceTitle(for look: DemoLook) -> String {
        if look.id == "feminine" { return "Onitsuka Tiger" }
        return "Casquette New York Yankees"
    }
}

private struct DemoListingCard: View {
    let listing: DemoListing

    private let imageHeight: CGFloat = 124

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingAssetImageView(imageName: listing.imageName)
                .frame(height: imageHeight)
                .frame(maxWidth: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.brand.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(OnboardingTheme.warmGrayMuted)
                    .lineLimit(1)
                Text(listing.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingTheme.offWhite)
                    .lineLimit(2)
                    .lineSpacing(2)

                HStack(alignment: .center) {
                    Text(listing.price)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(OnboardingTheme.accentRed)

                    Spacer(minLength: 8)

                    if let size = listing.size {
                        Text(size)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.offWhite.opacity(0.92))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                            }
                            .overlay {
                                Capsule()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(OnboardingTheme.cardFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OnboardingTheme.cardStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
    }
}
