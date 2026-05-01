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
        ZStack(alignment: .top) {
            stepContent
                .transition(stepTransition)

            if model.step != .hero && model.step != .paywall {
                progressBar
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.84), value: model.step)
        .statusBarHidden(true)
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .hero:
            OnboardingHeroView(model: model)
        case .gender:
            OnboardingGenderView(model: model)
        case .country:
            OnboardingCountryView(model: model)
        case .demo:
            OnboardingDemoView(model: model)
        case .paywall:
            OnboardingPaywallView(model: model)
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }

    // MARK: - Progress indicator

    private var progressBar: some View {
        let visibleSteps = OnboardingStep.allCases.filter { $0 != .hero }
        let currentIndex = visibleSteps.firstIndex(of: model.step) ?? 0

        return HStack(spacing: 5) {
            ForEach(visibleSteps.indices, id: \.self) { idx in
                Capsule()
                    .fill(idx <= currentIndex ? Color.accentColor : Color.white.opacity(0.25))
                    .frame(height: 4)
                    .frame(maxWidth: idx == currentIndex ? 28 : .infinity)
                    .animation(.spring(response: 0.4, dampingFraction: 0.72), value: currentIndex)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 56)
    }
}
