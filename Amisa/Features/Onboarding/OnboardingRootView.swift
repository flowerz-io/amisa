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
            let chromeBase = safeTop + 8
            let backRowHeight: CGFloat = showsGlobalBackChrome ? 40 : 0
            let progressBlockHeight: CGFloat = progressVisible
                ? (Self.progressTrackHeight + Self.progressBottomMargin + 4)
                : 0
            let contentTopInset = chromeBase + backRowHeight + progressBlockHeight

            ZStack(alignment: .top) {
                Group {
                    switch model.currentStep {
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
                    case .look:
                        OnboardingLookStepView(model: model)
                            .transition(slideHorizontal)
                    case .fakeAnalyzing:
                        OnboardingFakeAnalyzingView(model: model)
                            .transition(slideHorizontal)
                    case .fakeResults:
                        OnboardingFakeResultsView(model: model)
                            .transition(slideHorizontal)
                    case .paywall:
                        OnboardingPaywallView(model: model)
                            .transition(paywallTransition)
                    }
                }
                .padding(.top, contentTopInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack(alignment: .leading, spacing: 8) {
                    if showsGlobalBackChrome {
                        HStack {
                            Button {
                                model.previous()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .padding(10)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.95))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(String(localized: "Retour")))

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 20)
                    }

                    if progressVisible {
                        OnboardingProgressView(
                            currentSegmentFilled: filledProgressSegment,
                            totalSegments: OnboardingStep.progressSegmentsCount,
                            onSelectSegment: { segment in
                                model.goToProgressSegment(segment)
                            }
                        )
                        .padding(.horizontal, 32)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, chromeBase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .zIndex(100)
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: progressVisible)
            }
            .ignoresSafeArea(edges: .top)
            .ignoresSafeArea(edges: .bottom)
            .animation(.spring(response: 0.52, dampingFraction: 0.84), value: model.currentStep)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: filledProgressSegment)
            .sheet(isPresented: $model.isAuthSheetPresented) {
                AuthBottomSheet(
                    onSignedIn: {
                        model.closeAuthSheetAndContinueToGender()
                    },
                    onSkip: {
                        model.closeAuthSheetAndContinueToGender()
                    }
                )
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var filledProgressSegment: Int {
        model.currentStep.progressSegmentFilled()
    }

    /// Barre hors hero / paywall / phase « fake analysing ».

    private var progressVisible: Bool {
        switch model.currentStep {
        case .hero, .paywall, .fakeAnalyzing:
            return false
        default:
            return true
        }
    }

    /// Retour global (paywall : retour dans `OnboardingPaywallView`).
    private var showsGlobalBackChrome: Bool {
        switch model.currentStep {
        case .hero, .paywall:
            return false
        default:
            return true
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
}

// MARK: - OnboardingProgressView
//
// `currentSegmentFilled` : 1…5 segments remplis.

struct OnboardingProgressView: View {
    /// Segment actuellement « atteint » (1-based).
    let currentSegmentFilled: Int
    var totalSegments: Int = OnboardingStep.progressSegmentsCount
    var onSelectSegment: (Int) -> Void = { _ in }

    private static let segmentTouchHeight: CGFloat = 44

    var body: some View {
        let filled = max(0, min(totalSegments, currentSegmentFilled))

        HStack(alignment: .top, spacing: 6) {
            ForEach(1...max(1, totalSegments), id: \.self) { segment in
                Button {
                    onSelectSegment(segment)
                } label: {
                    ZStack(alignment: .top) {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: Self.segmentTouchHeight)
                            .contentShape(Rectangle())
                        Capsule()
                            .fill(segment <= filled ? BrandColors.primary : Color.primary.opacity(0.15))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, minHeight: Self.segmentTouchHeight, alignment: .top)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Étape \(segment) sur \(totalSegments)"))
                .accessibilityAddTraits(segment == filled ? [.isSelected] : [])
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: filled)
    }
}

// MARK: - OnboardingStepHeader

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
