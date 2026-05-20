//
//  OnboardingRootView.swift
//  Balibu
//

import SwiftUI

struct OnboardingRootView: View {
    @StateObject private var model: OnboardingFlowModel

    /// Hauteur réservée sous la barre : zone tactile min 44 pt + marge avant le contenu.
    private static let progressTrackHeight: CGFloat = 44
    private static let progressBottomMargin: CGFloat = 8

    init(onComplete: @escaping () -> Void) {
        _model = StateObject(wrappedValue: OnboardingFlowModel(onComplete: onComplete))
    }

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            /// Du bord supérieur de l’écran : safe area + 16 pt → ligne de progression (sous Dynamic Island).
            let progressTopPadding = safeTop + 16
            let contentTopInset = progressVisible
                ? progressTopPadding + Self.progressTrackHeight + Self.progressBottomMargin
                : 0

            ZStack(alignment: .top) {
                Group {
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
                    case .notifications:
                        NotificationOnboardingStepView(model: model)
                            .transition(slideHorizontal)
                    case .demo:
                        OnboardingDemoView(model: model)
                            .transition(slideHorizontal)
                    case .paywall:
                        OnboardingPaywallView(model: model)
                            .transition(paywallTransition)
                    }
                }
                .padding(.top, contentTopInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if progressVisible {
                    OnboardingProgressView(
                        currentStep: currentProgressStep,
                        totalSteps: 5,
                        onSelectSegment: { segment in
                            model.jumpToProgressSegment(segment)
                        }
                    )
                    .padding(.horizontal, 32)
                    .padding(.top, progressTopPadding)
                    .zIndex(100)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .ignoresSafeArea(edges: .top)
            .ignoresSafeArea(edges: .bottom)
            .animation(.spring(response: 0.52, dampingFraction: 0.84), value: model.step)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: currentProgressStep)
        }
    }

    private var progressVisible: Bool {
        model.step != .hero && model.step != .paywall
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

    // MARK: - Progress (5 segments : genre / zone / notifs / look-scan / résultats)

    private var currentProgressStep: Int {
        switch model.step {
        case .hero:          return 0
        case .gender:        return 1
        case .country:       return 2
        case .notifications: return 3
        case .demo:          return model.isDemoInResultsPhase ? 5 : 4
        case .paywall:       return 5
        }
    }
}

// MARK: - OnboardingProgressView
//
// `currentStep` est 1-based : segments 1…currentStep remplis.
// Chaque segment est cliquable pour sauter à l’étape correspondante.

struct OnboardingProgressView: View {
    let currentStep: Int
    var totalSteps: Int = 5
    var onSelectSegment: (Int) -> Void = { _ in }

    /// Zone tactile minimale par segment ; la capsule reste alignée en haut (pas centrée verticalement).
    private static let segmentTouchHeight: CGFloat = 44

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(1...max(1, totalSteps), id: \.self) { segment in
                Button {
                    onSelectSegment(segment)
                } label: {
                    ZStack(alignment: .top) {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: Self.segmentTouchHeight)
                            .contentShape(Rectangle())
                        Capsule()
                            .fill(segment <= currentStep ? BrandColors.primary : Color.primary.opacity(0.15))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, minHeight: Self.segmentTouchHeight, alignment: .top)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Étape \(segment) sur \(totalSteps)"))
                .accessibilityAddTraits(segment == currentStep ? [.isSelected] : [])
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: currentStep)
    }
}

// MARK: - OnboardingStepHeader
//
// Composant commun à toutes les pages onboarding (sauf hero et paywall).

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
