//
//  OnboardingHeroView.swift
//  Balibu
//
//  Écran d'introduction — floating listing cards + CTA principal.
//

import SwiftUI

// MARK: - Hero View

struct OnboardingHeroView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            heroBackground

            VStack(spacing: 0) {
                Spacer()

                floatingCardsLayer
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)

                Spacer(minLength: 24)

                headlineBlock
                    .padding(.horizontal, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)

                Spacer(minLength: 40)

                ctaButton
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Spacer(minLength: 44)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) {
                appeared = true
            }
        }
    }

    // MARK: - Background

    private var heroBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.18))
                .frame(width: 380)
                .blur(radius: 80)
                .offset(x: -90, y: -160)

            Circle()
                .fill(Color.purple.opacity(0.12))
                .frame(width: 320)
                .blur(radius: 70)
                .offset(x: 100, y: 200)
        }
    }

    // MARK: - Floating cards

    private var floatingCardsLayer: some View {
        ZStack {
            // Back card — blurred, offset right
            FloatingListingCard(
                listing: OnboardingMockListing.samples[1],
                phase: .init(floatAmplitude: 10, rotationDeg: 6, xOffset: 90, yOffset: 20)
            )
            .blur(radius: 2)
            .scaleEffect(0.88)
            .opacity(0.7)

            // Back card — blurred, offset left
            FloatingListingCard(
                listing: OnboardingMockListing.samples[2],
                phase: .init(floatAmplitude: 8, rotationDeg: -7, xOffset: -88, yOffset: 30)
            )
            .blur(radius: 3)
            .scaleEffect(0.84)
            .opacity(0.6)

            // Center foreground card — sharp
            FloatingListingCard(
                listing: OnboardingMockListing.samples[0],
                phase: .init(floatAmplitude: 14, rotationDeg: -2, xOffset: 0, yOffset: 0)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 10)

            // Small top-right accent card
            FloatingListingCard(
                listing: OnboardingMockListing.samples[3],
                phase: .init(floatAmplitude: 7, rotationDeg: 9, xOffset: 110, yOffset: -70)
            )
            .blur(radius: 1)
            .scaleEffect(0.70)
            .opacity(0.75)
        }
    }

    // MARK: - Headline (left-aligned)

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trouve instantanément\nles pièces que tu vois")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)

            Text("Importe une photo ou partage une image depuis Pinterest, Instagram ou TikTok. Balibu retrouve les annonces similaires sur les marketplaces.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.62))
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            model.advance()
        } label: {
            HStack(spacing: 8) {
                Text("Commencer")
                    .font(.system(size: 18, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.accentColor.opacity(0.4), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

// MARK: - Floating card component

private struct FloatingCardPhase {
    let floatAmplitude: CGFloat
    let rotationDeg: Double
    let xOffset: CGFloat
    let yOffset: CGFloat
}

private struct FloatingListingCard: View {
    let listing: OnboardingMockListing
    let phase: FloatingCardPhase

    var body: some View {
        cardContent
            .offset(x: phase.xOffset, y: phase.yOffset)
            .rotationEffect(.degrees(phase.rotationDeg))
            .phaseAnimator([false, true]) { view, isUp in
                view.offset(y: isUp ? -phase.floatAmplitude : 0)
            } animation: { isUp in
                .easeInOut(duration: isUp ? 2.8 : 2.4)
            }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Product image via asset (gradient fallback)
            OnboardingAssetImage(
                name: listing.imageName,
                fallbackColors: listing.gradientColors
            )
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Info row
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.brand)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .lineLimit(1)

                Text(listing.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(1)

                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Text(listing.price)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.accentColor)

                        if let size = listing.size {
                            Text(size)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.40))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    // Marketplace logo bottom-right
                    marketplaceLogo
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .frame(width: 152)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var marketplaceLogo: some View {
        let logoName = "logo_\(listing.source.lowercased())"
        if UIImage(named: logoName) != nil {
            Image(logoName)
                .resizable()
                .scaledToFit()
                .frame(height: 14)
                .opacity(0.70)
        } else {
            HStack(spacing: 3) {
                Circle()
                    .fill(listing.sourceColor)
                    .frame(width: 5, height: 5)
                Text(listing.source)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.58))
            }
        }
    }
}

// MARK: - Bouncy button style

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
