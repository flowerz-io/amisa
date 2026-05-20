//
//  OnboardingHeroView.swift
//  Balibu
//
//  Écran d'introduction — 3 cartes flottantes + headline + CTA.
//  Images : OnboardingMockData.heroCards → onboarding_hero_card_01/02/03
//

import SwiftUI

// MARK: - Hero View

struct OnboardingHeroView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false
    @State private var showAuthSheet = false

    private let cards = OnboardingMockData.heroCards

    var body: some View {
        ZStack {
            heroBackground

            VStack(spacing: 0) {
                Spacer()

                floatingCardsLayer
                    .frame(maxWidth: .infinity)
                    .frame(height: 400)

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
        .sheet(isPresented: $showAuthSheet) {
            AuthBottomSheet(
                onSignedIn: { model.advance() },
                onSkip:     { model.advance() }
            )
            .presentationDetents([.height(560)])
            .presentationCornerRadius(32)
            .presentationBackground(.ultraThinMaterial)
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

    // MARK: - Floating cards (3 cartes depuis OnboardingMockData.heroCards)
    //
    // ZStack render order (premier = derrière) :
    //   [0] ghost card (miroir de cards[2]) — très en arrière, basse et centrée
    //   [1] cards[1]  — arrière droit
    //   [2] cards[2]  — arrière gauche
    //   [3] cards[0]  — avant, carte principale (on top)

    private var floatingCardsLayer: some View {
        ZStack {
            // Ghost décoratif — derrière tout (pas de labels)
            if cards.count >= 3 {
                FloatingListingCard(
                    card: cards[2],
                    phase: .init(floatAmplitude: 6, rotationDeg: 5, xOffset: 30, yOffset: 78),
                    showLabels: false
                )
                .blur(radius: 5)
                .scaleEffect(0.65)
                .opacity(0.38)
            }

            // Carte arrière droite (+40% offsets)
            if cards.count >= 2 {
                FloatingListingCard(
                    card: cards[1],
                    phase: .init(floatAmplitude: 10, rotationDeg: 6, xOffset: 116, yOffset: 24)
                )
                .blur(radius: 2)
                .scaleEffect(0.88)
                .opacity(0.70)
            }

            // Carte arrière gauche (+40% offsets)
            if cards.count >= 3 {
                FloatingListingCard(
                    card: cards[2],
                    phase: .init(floatAmplitude: 8, rotationDeg: -7, xOffset: -114, yOffset: 36)
                )
                .blur(radius: 3)
                .scaleEffect(0.84)
                .opacity(0.60)
            }

            // Carte principale — au premier plan
            if let main = cards.first {
                FloatingListingCard(
                    card: main,
                    phase: .init(floatAmplitude: 14, rotationDeg: -2, xOffset: 0, yOffset: 0)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 28, x: 0, y: 12)
            }
        }
    }

    // MARK: - Headline

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trouve instantanément\nles pièces que tu vois")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)

            Text("Importe une photo ou partage une image depuis Pinterest, Instagram ou TikTok. Amisa retrouve les meilleures annonces Vinted similaires.")
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
            showAuthSheet = true
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
    let card: OnboardingHeroCardData
    let phase: FloatingCardPhase
    var showLabels: Bool = true

    private let heroProviderLogoSize: CGFloat = 21  // 14 × 1.5

    var body: some View {
        cardContent
            .offset(x: phase.xOffset, y: phase.yOffset)
            .rotationEffect(.degrees(phase.rotationDeg))
            .phaseAnimator([false, true]) { view, isUp in
                view.offset(y: isUp ? -phase.floatAmplitude : 0)
            } animation: { _ in
                .easeInOut(duration: 2.8)
            }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image produit +40% — asset ou placeholder
            OnboardingAssetImageView(imageName: card.imageName)
                .frame(height: 154)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if showLabels {
                infoRow
            }
        }
        .frame(width: 213)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var infoRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(card.brand)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.48))
                .lineLimit(1)

            Text(card.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)

            HStack(alignment: .center) {
                HStack(spacing: 7) {
                    Text(card.price)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.accentColor)

                    if let size = card.size {
                        Text(size)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.40))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                providerLogo
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var providerLogo: some View {
        if UIImage(named: card.providerLogoName) != nil {
            Image(card.providerLogoName)
                .resizable()
                .scaledToFit()
                .frame(height: heroProviderLogoSize)
                .opacity(0.70)
        } else {
            Text(card.providerLogoName.replacingOccurrences(of: "provider_", with: ""))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.50))
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
