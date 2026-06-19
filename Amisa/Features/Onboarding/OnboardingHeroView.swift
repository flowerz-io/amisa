//
//  OnboardingHeroView.swift
//  Amisa
//

import SwiftUI

struct OnboardingHeroView: View {
    @ObservedObject var model: OnboardingFlowModel
    @Environment(\.onboardingLayoutMetrics) private var metrics
    @StateObject private var parallax = OnboardingParallaxMotion()
    @State private var appeared = false
    @State private var floatPhase = false
    private let cards = OnboardingMockData.heroCards

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepScroll {
                VStack(spacing: metrics.isCompactHeight ? 20 : 28) {
                    floatingCardsLayer
                        .frame(height: metrics.heroCardsHeight)
                        .scaleEffect(appeared ? 1 : 0.94)
                        .opacity(appeared ? 1 : 0)

                    headlineBlock
                        .padding(.horizontal, metrics.horizontalPadding)
                        .onboardingStepEntrance(appeared, delay: 0.12)
                }
                .padding(.top, 8)
            }

            OnboardingPinnedFooter {
                OnboardingPrimaryButton(title: String(localized: "Commencer")) {
                    model.openAuthSheet()
                }
                .onboardingStepEntrance(appeared, delay: 0.2)
            }
        }
        .onAppear {
            parallax.start()
            withAnimation(OnboardingMotion.springPremium.delay(0.08)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: OnboardingMotion.floatDuration).repeatForever(autoreverses: true)) {
                floatPhase = true
            }
        }
        .onDisappear {
            parallax.stop()
        }
    }

    private var floatingCardsLayer: some View {
        ZStack {
            if cards.count >= 2 {
                HeroFloatingCard(
                    card: cards[1],
                    imageHeight: metrics.heroCardImageHeight,
                    x: 62, y: 28,
                    rotation: 9, scale: 0.86,
                    floatPhase: floatPhase,
                    depth: 0,
                    parallax: parallax.offset
                )
                .blur(radius: 2)
                .opacity(0.78)
            }
            if cards.count >= 3 {
                HeroFloatingCard(
                    card: cards[2],
                    imageHeight: metrics.heroCardImageHeight,
                    x: -58, y: 44,
                    rotation: -11, scale: 0.82,
                    floatPhase: floatPhase,
                    depth: 1,
                    parallax: parallax.offset
                )
                .blur(radius: 2.5)
                .opacity(0.72)
            }
            if cards.count >= 1 {
                HeroFloatingCard(
                    card: cards[0],
                    imageHeight: metrics.heroCardImageHeight,
                    x: 0, y: 0,
                    rotation: -2.5, scale: 1,
                    floatPhase: floatPhase,
                    depth: 2,
                    parallax: parallax.offset
                )
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var headlineBlock: some View {
        let titleFont = Font.system(size: metrics.stepTitleSize, weight: .bold)

        return VStack(alignment: .leading, spacing: metrics.isCompactHeight ? 10 : 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trouve")
                    .font(titleFont)
                    .foregroundStyle(OnboardingTheme.offWhite)

                HeroLavaGradientText(text: "instantanément", font: titleFont)

                Text("les pièces que tu vois")
                    .font(titleFont)
                    .foregroundStyle(OnboardingTheme.offWhite)
            }
            .tracking(-0.2)

            Text("Importe une photo ou partage une image. Amisa retrouve les annonces Vinted similaires.")
                .font(.system(size: metrics.stepSubtitleSize, weight: .regular))
                .foregroundStyle(OnboardingTheme.warmGray)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Titre « instantanément » — gradient lava subtil

private struct HeroLavaGradientText: View {
    let text: String
    let font: Font

    private static let warmOrange = Color(red: 232 / 255, green: 58 / 255, blue: 48 / 255)

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(.clear)
            .background {
                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let waveA = sin(t * 0.55) * 0.5 + 0.5
                    let waveB = cos(t * 0.42 + 1.2) * 0.5 + 0.5
                    let waveC = sin(t * 0.31 + 2.4) * 0.5 + 0.5

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    OnboardingTheme.accentRed,
                                    Self.warmOrange,
                                    OnboardingTheme.accentRed.opacity(0.92),
                                    Self.warmOrange.opacity(0.88),
                                ],
                                startPoint: UnitPoint(x: waveA * 0.45 + waveC * 0.1, y: 0.05),
                                endPoint: UnitPoint(x: 0.3 + waveB * 0.5, y: 0.95)
                            )
                        )
                }
            }
            .mask {
                Text(text)
                    .font(font)
            }
    }
}

private struct HeroFloatingCard: View {
    let card: OnboardingHeroCardData
    let imageHeight: CGFloat
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let scale: CGFloat
    let floatPhase: Bool
    let depth: Int
    let parallax: CGSize

    private var depthFactor: CGFloat {
        switch depth {
        case 2: 1
        case 1: 0.55
        default: 0.3
        }
    }

    private var floatOffset: CGFloat {
        floatPhase ? (depth == 2 ? -11 : depth == 1 ? -7 : -5) : (depth == 2 ? 7 : 5)
    }

    private var organicRotation: Double {
        rotation + (floatPhase ? (depth == 2 ? 1.2 : 0.8) : -0.6)
    }

    var body: some View {
        OnboardingGlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingAssetImageView(imageName: card.imageName)
                    .frame(height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.brand.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(OnboardingTheme.warmGray)
                    Text(card.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.offWhite)
                        .lineLimit(1)
                    Text(card.price)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(OnboardingTheme.accentRed)
                }
                .padding(14)
            }
        }
        .frame(width: min(212, imageHeight * 1.35))
        .offset(
            x: x + parallax.width * depthFactor,
            y: y + floatOffset + parallax.height * depthFactor
        )
        .rotationEffect(.degrees(organicRotation))
        .scaleEffect(scale)
        .animation(
            .easeInOut(duration: OnboardingMotion.floatDuration + Double(depth) * 0.35)
                .repeatForever(autoreverses: true),
            value: floatPhase
        )
    }
}
