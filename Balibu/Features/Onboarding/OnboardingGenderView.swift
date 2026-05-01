//
//  OnboardingGenderView.swift
//  Balibu
//
//  Étape 2 — sélection du genre avec deux cartes premium full-height.
//

import SwiftUI

struct OnboardingGenderView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false
    @State private var pressedGender: OnboardingGender?
    @Namespace private var ns

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                headerText
                    .padding(.top, 96)
                    .padding(.horizontal, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)

                Spacer(minLength: 28)

                genderCards

                Spacer(minLength: 32)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var headerText: some View {
        VStack(spacing: 8) {
            Text("Tu recherches\nprincipalement pour :")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("On adapte les résultats, les tailles et les suggestions.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Cards

    private var genderCards: some View {
        HStack(spacing: 12) {
            genderCard(.female, index: 0)
            genderCard(.male, index: 1)
        }
        .padding(.horizontal, 20)
    }

    private func genderCard(_ gender: OnboardingGender, index: Int) -> some View {
        let isSelected = model.gender == gender

        return Button {
            selectGender(gender)
        } label: {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: isSelected ? gender.gradientColors : [
                        Color(uiColor: .secondarySystemGroupedBackground),
                        Color(uiColor: .secondarySystemGroupedBackground),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 16) {
                    Spacer()

                    // Outfit emoji collage
                    outfitCollage(for: gender, isSelected: isSelected)
                        .phaseAnimator([false, true]) { view, up in
                            view.offset(y: up ? -6 : 0)
                                .scaleEffect(up ? 1.04 : 1.0)
                        } animation: { _ in .easeInOut(duration: 3.0) }

                    Text(gender.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .primary)

                    Spacer(minLength: 40)
                }

                // Selection ring
                if isSelected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        .matchedGeometryEffect(id: "selection_ring", in: ns)
                }
            }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color(uiColor: .separator), lineWidth: 1)
            }
            .shadow(
                color: isSelected ? gender.gradientColors.last!.opacity(0.35) : .clear,
                radius: 20, x: 0, y: 8
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 40)
        .animation(
            .spring(response: 0.55, dampingFraction: 0.78).delay(Double(index) * 0.08 + 0.15),
            value: appeared
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isSelected)
    }

    // MARK: - Outfit collage

    @ViewBuilder
    private func outfitCollage(for gender: OnboardingGender, isSelected: Bool) -> some View {
        let emojis = gender.outfitEmojis
        let tint: Color = isSelected ? .white : Color.primary.opacity(0.75)

        VStack(spacing: 2) {
            Text(emojis[0])
                .font(.system(size: 54))
                .shadow(color: .black.opacity(0.20), radius: 6)

            HStack(spacing: 8) {
                if emojis.count > 1 {
                    Text(emojis[1])
                        .font(.system(size: 36))
                }
                if emojis.count > 2 {
                    Text(emojis[2])
                        .font(.system(size: 32))
                }
            }
        }
        .colorMultiply(isSelected ? .white : tint)
    }

    // MARK: - Action

    private func selectGender(_ gender: OnboardingGender) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            model.gender = gender
        }
        // Auto-advance after brief confirmation moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            model.advance()
        }
    }
}
