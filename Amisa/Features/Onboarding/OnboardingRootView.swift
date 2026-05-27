//
//  OnboardingRootView.swift
//  Amisa
//

import SwiftUI

struct OnboardingRootView: View {
    @StateObject private var model: OnboardingFlowModel

    private static let progressTrackHeight: CGFloat = 6
    private static let chromeTopPadding: CGFloat = 8

    init(onComplete: @escaping () -> Void) {
        _model = StateObject(wrappedValue: OnboardingFlowModel(onComplete: onComplete))
    }

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let backRowHeight: CGFloat = showsBackButton ? 44 : 0
            let progressHeight: CGFloat = model.step.showsProgressBar
                ? (Self.progressTrackHeight + 16)
                : 0
            let topInset = safeTop + Self.chromeTopPadding + backRowHeight + progressHeight

            ZStack(alignment: .top) {
                stepContent
                    .padding(.top, topInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                chrome(safeTop: safeTop)
            }
        }
        .sheet(isPresented: $model.isAuthSheetPresented) {
            OnboardingAuthSheetView(model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch model.step {
            case .hero:
                OnboardingHeroView(model: model)
            case .gender:
                OnboardingGenderView(model: model)
            case .country:
                OnboardingCountryView(model: model)
            case .notifications:
                NotificationOnboardingStepView(model: model)
            case .look:
                OnboardingLookView(model: model)
            case .fakeAnalysis:
                OnboardingFakeAnalysisView(model: model)
            case .fakeResults:
                OnboardingFakeResultsView(model: model)
            case .paywall:
                OnboardingPaywallView(model: model)
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.84), value: model.step)
    }

    private var showsBackButton: Bool {
        model.step != .hero
    }

    @ViewBuilder
    private func chrome(safeTop: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsBackButton {
                HStack {
                    Button {
                        model.back()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(backButtonForeground)
                            .padding(10)
                            .background(backButtonBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(String(localized: "Retour")))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
            }

            if model.step.showsProgressBar {
                OnboardingProgressBar(
                    filledSegments: model.step.progressSegment,
                    totalSegments: OnboardingFlowModel.progressSegmentCount
                )
                .padding(.horizontal, 24)
            }
        }
        .padding(.top, safeTop + Self.chromeTopPadding)
    }

    private var backButtonForeground: Color {
        model.step == .paywall ? .white.opacity(0.92) : .primary
    }

    private var backButtonBackground: Color {
        model.step == .paywall
            ? Color.white.opacity(0.08)
            : Color(uiColor: .secondarySystemGroupedBackground).opacity(0.95)
    }
}

// MARK: - Progress bar (non cliquable)

struct OnboardingProgressBar: View {
    let filledSegments: Int
    let totalSegments: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...totalSegments, id: \.self) { segment in
                Capsule()
                    .fill(segment <= filledSegments ? BrandColors.primary : Color(uiColor: .tertiarySystemFill))
                    .frame(height: 6)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - En-tête d’étape

struct OnboardingStepHeader: View {
    let segment: Int
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Étape \(segment) sur \(OnboardingFlowModel.progressSegmentCount)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
}
