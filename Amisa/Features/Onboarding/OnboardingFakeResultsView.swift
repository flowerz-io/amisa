//
//  OnboardingFakeResultsView.swift
//  Amisa
//

import SwiftUI

struct OnboardingFakeResultsView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false

    private var look: DemoLook? { model.selectedLook }
    private var listings: [DemoListing] { look?.results ?? [] }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            if let look {
                VStack(spacing: 0) {
                    resultsHeader(look: look)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(listings) { listing in
                                DemoListingCard(listing: listing)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120)
                    }

                    ctaBar
                }
                .opacity(appeared ? 1 : 0)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.05)) {
                appeared = true
            }
        }
    }

    private func resultsHeader(look: DemoLook) -> some View {
        HStack(spacing: 14) {
            OnboardingAssetImageView(imageName: look.imageName)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Annonces similaires trouvées")
                .font(.system(size: 17, weight: .bold))
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var ctaBar: some View {
        VStack(spacing: 0) {
            Button {
                model.next()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("Analyser avec ma propre photo")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(BrandColors.primaryLinearGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(BouncyButtonStyle())
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 28)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

private struct DemoListingCard: View {
    let listing: DemoListing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingAssetImageView(imageName: listing.imageName)
                .frame(height: 130)
                .clipped()

            VStack(alignment: .leading, spacing: 3) {
                Text(listing.brand)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(listing.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(listing.price)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BrandColors.primary)
            }
            .padding(8)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
