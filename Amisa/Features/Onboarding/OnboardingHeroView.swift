//
//  OnboardingHeroView.swift
//  Amisa
//

import SwiftUI

struct OnboardingHeroView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false

    private let cards = OnboardingMockData.heroCards

    var body: some View {
        ZStack {
            heroBackground

            VStack(spacing: 0) {
                Spacer()

                floatingCardsLayer
                    .frame(height: 380)

                Spacer(minLength: 20)

                headlineBlock
                    .padding(.horizontal, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)

                Spacer(minLength: 32)

                Button {
                    model.openAuthSheet()
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
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 14, x: 0, y: 6)
                }
                .buttonStyle(BouncyButtonStyle())
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 40)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.82).delay(0.12)) {
                appeared = true
            }
        }
    }

    private var heroBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Circle()
                .fill(Color.accentColor.opacity(0.18))
                .frame(width: 360)
                .blur(radius: 80)
                .offset(x: -80, y: -140)
        }
    }

    private var floatingCardsLayer: some View {
        ZStack {
            if cards.count >= 2 {
                HeroFloatingCard(card: cards[1], x: 56, y: 24, rotation: 8, scale: 0.88)
                    .blur(radius: 2)
                    .opacity(0.85)
            }
            if cards.count >= 3 {
                HeroFloatingCard(card: cards[2], x: -52, y: 40, rotation: -10, scale: 0.84)
                    .blur(radius: 2)
                    .opacity(0.8)
            }
            if cards.count >= 1 {
                HeroFloatingCard(card: cards[0], x: 0, y: 0, rotation: -2, scale: 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trouve instantanément\nles pièces que tu vois")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            Text("Importe une photo ou partage une image. Amisa retrouve les meilleures annonces Vinted similaires.")
                .font(.system(size: 15))
                .foregroundStyle(Color.white.opacity(0.62))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HeroFloatingCard: View {
    let card: OnboardingHeroCardData
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingAssetImageView(imageName: card.imageName)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(card.brand)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                Text(card.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                Text(card.price)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(12)
        }
        .frame(width: 200)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .offset(x: x, y: y)
        .rotationEffect(.degrees(rotation))
        .scaleEffect(scale)
    }
}

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
