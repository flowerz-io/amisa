//
//  OnboardingGenderView.swift
//  Balibu
//
//  Étape 2 — sélection du genre avec deux cartes full-height.
//

import SwiftUI

struct OnboardingGenderView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false
    @Namespace private var ns

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                headerText
                    // 128pt from top ensures clearance above the progress bar
                    // even on Dynamic Island devices (safe area ~59pt + bar at 56pt)
                    .padding(.top, 128)
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

                    // SF Symbol pictogram (neutre, sans connotation vestimentaire)
                    Image(systemName: gender.icon)
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(isSelected ? .white : Color.primary.opacity(0.65))
                        .phaseAnimator([false, true]) { view, up in
                            view.offset(y: up ? -5 : 0)
                                .scaleEffect(up ? 1.04 : 1.0)
                        } animation: { _ in .easeInOut(duration: 3.2) }

                    Text(gender.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .primary)

                    Spacer(minLength: 40)
                }

                // Selection ring
                if isSelected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 2.5)
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

    // MARK: - Action

    private func selectGender(_ gender: OnboardingGender) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            model.gender = gender
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            model.advance()
        }
    }
}
