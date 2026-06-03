//
//  OnboardingRootView.swift
//  Amisa
//

import SwiftUI

struct OnboardingRootView: View {
    @StateObject private var model: OnboardingFlowModel

    private static let chromeRowHeight: CGFloat = 40
    /// Espace sous la safe area avant le chrome.
    private static let chromeTopPadding: CGFloat = 12
    /// Marge supplémentaire au-dessus de la ligne retour + progression.
    private static let chromeRowExtraTopMargin: CGFloat = 40

    init(onComplete: @escaping () -> Void) {
        _model = StateObject(wrappedValue: OnboardingFlowModel(onComplete: onComplete))
    }

    var body: some View {
        ZStack {
            OnboardingCinematicBackground(glowIntensity: backgroundGlowIntensity)

            GeometryReader { geo in
                let safeTop = geo.safeAreaInsets.top
                let showsChrome = showsBackButton || model.step.showsProgressBar
                let chromeBlock = showsChrome
                    ? (Self.chromeRowExtraTopMargin + Self.chromeRowHeight)
                    : 0
                let topInset = safeTop + Self.chromeTopPadding + chromeBlock

                ZStack(alignment: .top) {
                    stepContent
                        .padding(.top, topInset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    chrome(safeTop: safeTop)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .overlay {
            if model.isAuthSheetPresented {
                OnboardingAuthSheetView(model: model)
                    .zIndex(50)
            }
        }
        .animation(OnboardingMotion.springPremium, value: model.isAuthSheetPresented)
    }

    private var backgroundGlowIntensity: CGFloat {
        switch model.step {
        case .paywall: 1.18
        case .hero: 1.05
        case .fakeAnalysis, .fakeResults: 1.02
        default: 0.92
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        ZStack {
            stepLayer(.hero) { OnboardingHeroView(model: model) }
            stepLayer(.gender) { OnboardingGenderView(model: model) }
            stepLayer(.country) { OnboardingCountryView(model: model) }
            stepLayer(.notifications) { NotificationOnboardingStepView(model: model) }
            stepLayer(.look) { OnboardingLookView(model: model) }
            stepLayer(.fakeAnalysis) { OnboardingFakeAnalysisView(model: model) }
            stepLayer(.fakeResults) { OnboardingFakeResultsView(model: model) }
            stepLayer(.paywall) { OnboardingPaywallView(model: model) }
        }
        .animation(OnboardingMotion.springPremium, value: model.step)
    }

    @ViewBuilder
    private func stepLayer<Content: View>(
        _ step: OnboardingStep,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if model.step == step {
            content()
                .onboardingStepChangeTransition()
        }
    }

    private var showsBackButton: Bool {
        model.step != .hero
    }

    @ViewBuilder
    private func chrome(safeTop: CGFloat) -> some View {
        if showsBackButton || model.step.showsProgressBar {
            HStack(alignment: .center, spacing: 12) {
                if showsBackButton {
                    OnboardingBackButton { model.back() }
                }

                if model.step.showsProgressBar {
                    OnboardingProgressBar(
                        filledSegments: model.step.progressSegment,
                        totalSegments: OnboardingFlowModel.progressSegmentCount
                    )
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(height: Self.chromeRowHeight)
            .padding(.horizontal, 20)
            .padding(.top, safeTop + Self.chromeTopPadding + Self.chromeRowExtraTopMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
