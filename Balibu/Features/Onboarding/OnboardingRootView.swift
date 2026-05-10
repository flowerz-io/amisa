//
//  OnboardingRootView.swift
//  Balibu
//

import SwiftUI

struct OnboardingRootView: View {
    @StateObject private var model: OnboardingFlowModel

    init(onComplete: @escaping () -> Void) {
        _model = StateObject(wrappedValue: OnboardingFlowModel(onComplete: onComplete))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                stepContent

                if model.step != .hero && model.step != .paywall {
                    progressBar
                        // Constantes centralisées : safeAreaTop + 12 px, 32 px horizontal
                        .padding(.horizontal, 32)
                        .padding(.top, geo.safeAreaInsets.top + 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .zIndex(10)
                }
            }
            .animation(.spring(response: 0.52, dampingFraction: 0.84), value: model.step)
            .statusBarHidden(true)
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .hero:
            OnboardingHeroView(model: model)
                .transition(heroTransition)
        case .gender:
            OnboardingGenderView(model: model)
                .transition(slideHorizontal)
        case .country:
            OnboardingCountryView(model: model)
                .transition(slideHorizontal)
        case .demo:
            OnboardingDemoView(model: model)
                .transition(slideHorizontal)
        case .paywall:
            OnboardingPaywallView(model: model)
                .transition(paywallTransition)
        }
    }

    // MARK: - Transitions

    private var heroTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity,
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var slideHorizontal: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var paywallTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal:   .move(edge: .bottom).combined(with: .opacity)
        )
    }

    // MARK: - Progress bar (4 étapes : genre / zone / look-scan / résultats)
    // Positionnée par le GeometryReader du body : safeAreaTop + 12

    private var progressBar: some View {
        OnboardingProgressView(
            currentStep: currentProgressStep,
            totalSteps: 4
        )
    }

    private var currentProgressStep: Int {
        switch model.step {
        case .hero:    return 0
        case .gender:  return 1
        case .country: return 2
        case .demo:    return model.isDemoInResultsPhase ? 4 : 3
        case .paywall: return 4
        }
    }
}

// MARK: - OnboardingProgressView
//
// currentStep est 1-based.
// Segments d'index < currentStep sont orange (AccentColor).
// Tous les segments ont la même largeur.

struct OnboardingProgressView: View {
    let currentStep: Int
    var totalSteps: Int = 4

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(1, totalSteps), id: \.self) { index in
                Capsule()
                    .fill(index < currentStep ? Color.accentColor : Color.primary.opacity(0.15))
                    .frame(height: 4)
                    .animation(.spring(response: 0.38, dampingFraction: 0.74), value: currentStep)
            }
        }
    }
}

// MARK: - OnboardingStepHeader
//
// Composant commun à toutes les pages onboarding (sauf hero et paywall).
// Placer Spacer(minLength: 195) AVANT ce composant dans chaque vue
// pour un positionnement vertical identique sur toutes les pages.
//
// currentStep : 1=genre  2=zone  3=look/scan  4=résultats

struct OnboardingStepHeader: View {
    let currentStep: Int
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text(subtitle)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
    }
}
