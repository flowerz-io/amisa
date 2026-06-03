//
//  OnboardingLookView.swift
//  Amisa
//

import SwiftUI

/// Portrait éditorial mode : largeur:hauteur = 3:5.
private let lookCardWidthToHeight: CGFloat = 3 / 5
private let immersiveLookSpacing: CGFloat = 14
private let immersiveLookHorizontalPadding: CGFloat = 12

struct OnboardingLookView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(
                segment: 4,
                title: "Choisis un look\nà analyser",
                subtitle: "Amisa va retrouver les pièces similaires pour toi."
            )
            .padding(.top, 8)
            .onboardingStepEntrance(appeared)

            Spacer()

            GeometryReader { geo in
                let cardSize = lookCardSize(in: geo.size)
                HStack(alignment: .center, spacing: immersiveLookSpacing) {
                    ForEach(Array(model.demoLooks.enumerated()), id: \.element.id) { index, look in
                        Button {
                            model.selectLook(look)
                        } label: {
                            ImmersiveLookCard(look: look)
                                .frame(width: cardSize.width, height: cardSize.height)
                        }
                        .buttonStyle(OnboardingSelectablePressStyle())
                        .onboardingStaggeredEntrance(appeared, index: index, baseDelay: 0.08)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            }
            .padding(.horizontal, immersiveLookHorizontalPadding)

            Spacer()
        }
        .onboardingScreen()
        .onAppear {
            withAnimation(OnboardingMotion.springPremium.delay(0.06)) {
                appeared = true
            }
        }
    }

    /// Dimensions identiques pour les deux cards, ratio 3:5, maximisées (le padding horizontal est déjà appliqué au conteneur).
    private func lookCardSize(in size: CGSize) -> CGSize {
        let maxCardWidth = (size.width - immersiveLookSpacing) / 2
        let width = min(maxCardWidth, size.height * lookCardWidthToHeight)
        let height = width / lookCardWidthToHeight
        return CGSize(width: width, height: height)
    }
}

private struct ImmersiveLookCard: View {
    let look: DemoLook

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            OnboardingAssetImageView(imageName: look.imageName, focusRect: look.focusRect)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.72),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(look.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(OnboardingTheme.offWhite)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                Text(look.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OnboardingTheme.offWhite.opacity(0.75))
                    .lineLimit(1)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 12)
        .shadow(color: OnboardingTheme.accentRed.opacity(0.06), radius: 16, x: 0, y: 4)
    }
}
