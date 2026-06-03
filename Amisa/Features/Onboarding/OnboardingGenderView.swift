//
//  OnboardingGenderView.swift
//  Amisa
//

import SwiftUI

struct OnboardingGenderView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false
    @State private var highlightedId: String?

    private let options: [(id: String, label: String, editorialIcon: String)] = [
        ("Femme", "Femme", "figure.stand.dress"),
        ("Homme", "Homme", "figure.stand"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(
                segment: 1,
                title: "Tu recherches\nprincipalement pour :",
                subtitle: "On adapte les résultats, les tailles et les suggestions."
            )
            .padding(.top, 8)
            .onboardingStepEntrance(appeared)

            Spacer(minLength: 24)

            HStack(spacing: 14) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    genderCard(option)
                        .onboardingStaggeredEntrance(appeared, index: index + 1, baseDelay: 0.08)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .onboardingScreen()
        .onAppear {
            withAnimation(OnboardingMotion.springPremium.delay(0.04)) {
                appeared = true
            }
        }
    }

    private func genderCard(_ option: (id: String, label: String, editorialIcon: String)) -> some View {
        let isHighlighted = highlightedId == option.id

        return Button {
            highlightedId = option.id
            withAnimation(OnboardingMotion.springSnappy) {}
            Task {
                try? await Task.sleep(for: .milliseconds(220))
                model.selectGender(option.id)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(OnboardingTheme.cardFill)
                    .overlay {
                        if isHighlighted {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            OnboardingTheme.accentRed.opacity(0.22),
                                            OnboardingTheme.accentRed.opacity(0.06),
                                            Color.clear,
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }

                VStack(spacing: 0) {
                    Spacer()
                    Image(systemName: option.editorialIcon)
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundStyle(OnboardingTheme.offWhite.opacity(0.78))
                        .symbolRenderingMode(.hierarchical)
                        .padding(.bottom, 8)
                    Text(option.label)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(OnboardingTheme.offWhite)
                    Spacer(minLength: 32)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isHighlighted
                            ? OnboardingTheme.accentRed.opacity(0.55)
                            : OnboardingTheme.cardStroke,
                        lineWidth: isHighlighted ? 1.5 : 1
                    )
            }
            .shadow(
                color: .black.opacity(isHighlighted ? 0.42 : 0.32),
                radius: isHighlighted ? 20 : 14,
                x: 0,
                y: isHighlighted ? 12 : 8
            )
            .onboardingSelectionGlow(isSelected: isHighlighted)
        }
        .buttonStyle(OnboardingSelectablePressStyle(isSelected: isHighlighted))
        .animation(OnboardingMotion.springSnappy, value: isHighlighted)
    }
}
