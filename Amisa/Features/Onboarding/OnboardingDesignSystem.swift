//
//  OnboardingDesignSystem.swift
//  Amisa
//
//  DA premium onboarding — sombre, éditorial, fashion tech.
//

import SwiftUI

// MARK: - Layout responsive (iPhone + iPad)

struct OnboardingLayoutMetrics: Equatable {
    let size: CGSize
    let safeTop: CGFloat
    let safeBottom: CGFloat

    init(size: CGSize, safeArea: EdgeInsets) {
        self.size = size
        self.safeTop = safeArea.top
        self.safeBottom = safeArea.bottom
    }

    var width: CGFloat { size.width }
    var height: CGFloat { size.height }
    var isPad: Bool { width >= 600 }
    var isLandscape: Bool { width > height }
    var isCompactHeight: Bool { height < 700 }
    var isVeryCompactHeight: Bool { height < 580 }

    var maxContentWidth: CGFloat {
        isPad ? min(560, width - 48) : width
    }

    var horizontalPadding: CGFloat { isPad ? 32 : 20 }

    var footerBottomPadding: CGFloat {
        max(safeBottom, isPad ? 20 : 12) + 8
    }

    var scrollBottomPadding: CGFloat { 20 }

    var stepTitleSize: CGFloat {
        if isVeryCompactHeight { return 26 }
        if isPad && !isLandscape { return 36 }
        return isCompactHeight ? 28 : 32
    }

    var stepSubtitleSize: CGFloat { isCompactHeight ? 14 : 16 }

    var heroCardsHeight: CGFloat {
        let ratio: CGFloat = isLandscape ? 0.36 : 0.40
        return min(400, max(200, height * ratio))
    }

    var heroCardImageHeight: CGFloat {
        if isVeryCompactHeight { return 108 }
        if isPad { return 156 }
        return isCompactHeight ? 124 : 148
    }

    var genderCardHeight: CGFloat {
        min(280, max(170, height * 0.34))
    }

    var genderIconSize: CGFloat {
        if isVeryCompactHeight { return 48 }
        return isPad ? 72 : 60
    }

    var notificationMockupHeight: CGFloat {
        min(320, max(190, height * 0.34))
    }

    var paywallHeroTitleSize: CGFloat {
        if isVeryCompactHeight { return 24 }
        return isPad ? 32 : 28
    }

    var paywallBenefitSpacing: CGFloat { isCompactHeight ? 8 : 10 }
}

private struct OnboardingLayoutMetricsKey: EnvironmentKey {
    static let defaultValue = OnboardingLayoutMetrics(
        size: CGSize(width: 390, height: 844),
        safeArea: EdgeInsets()
    )
}

extension EnvironmentValues {
    var onboardingLayoutMetrics: OnboardingLayoutMetrics {
        get { self[OnboardingLayoutMetricsKey.self] }
        set { self[OnboardingLayoutMetricsKey.self] = newValue }
    }
}

/// Contenu défilant avec largeur max centrée (iPad).
struct OnboardingStepScroll<Content: View>: View {
    @Environment(\.onboardingLayoutMetrics) private var metrics
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content()
                .frame(maxWidth: metrics.maxContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.bottom, metrics.scrollBottomPadding)
        }
    }
}

/// Pied de page fixe (CTA toujours visible, safe area incluse).
struct OnboardingPinnedFooter<Content: View>: View {
    @Environment(\.onboardingLayoutMetrics) private var metrics
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, metrics.footerBottomPadding)
    }
}

// MARK: - Palette

enum OnboardingTheme {
    static let deepBlack = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
    static let accentRed = Color(red: 217 / 255, green: 31 / 255, blue: 38 / 255)
    static let offWhite = Color(red: 246 / 255, green: 243 / 255, blue: 239 / 255)
    static let warmGray = Color(red: 168 / 255, green: 158 / 255, blue: 148 / 255)
    static let warmGrayMuted = Color(red: 120 / 255, green: 112 / 255, blue: 106 / 255)
    /// Surface carte — jamais de Material système (évite le blanc laiteux).
    static let cardFill = Color(red: 28 / 255, green: 26 / 255, blue: 25 / 255)
    static let cardFillElevated = Color(red: 36 / 255, green: 33 / 255, blue: 32 / 255)
    static let cardStroke = Color.white.opacity(0.1)
    static let glassHighlight = Color.white.opacity(0.06)
    /// Panneau modal auth — verre fumé sombre opaque.
    static let panelFill = Color(red: 22 / 255, green: 20 / 255, blue: 20 / 255)
    static let skeletonTop = Color(red: 34 / 255, green: 31 / 255, blue: 30 / 255)
    static let skeletonBottom = Color(red: 18 / 255, green: 16 / 255, blue: 15 / 255)

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                accentRed,
                Color(red: 232 / 255, green: 58 / 255, blue: 48 / 255),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var screenGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 14 / 255, green: 10 / 255, blue: 10 / 255),
                deepBlack,
                Color(red: 18 / 255, green: 8 / 255, blue: 8 / 255),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Fond cinématique

struct OnboardingCinematicBackground: View {
    var glowIntensity: CGFloat = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 8)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let breathe = CGFloat(sin(t * 0.55) * 0.5 + 0.5)
            let drift = CGFloat(cos(t * 0.32) * 0.5 + 0.5)

            ZStack {
                OnboardingTheme.screenGradient
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color(red: 22 / 255, green: 10 / 255, blue: 12 / 255).opacity(0.5 + breathe * 0.08),
                        OnboardingTheme.deepBlack,
                        Color(red: 12 / 255, green: 8 / 255, blue: 14 / 255),
                    ],
                    startPoint: UnitPoint(x: 0.15 + drift * 0.1, y: 0),
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        OnboardingTheme.accentRed.opacity(0.08 + 0.04 * breathe * glowIntensity),
                        .clear,
                    ],
                    center: UnitPoint(x: 0.82 + drift * 0.03, y: 0.12),
                    startRadius: 24,
                    endRadius: 420
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.62),
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: 540
                )
                .ignoresSafeArea()

                Circle()
                    .fill(OnboardingTheme.accentRed.opacity(0.04 + 0.02 * breathe * glowIntensity))
                    .frame(width: 280)
                    .blur(radius: 64)
                    .offset(x: -110, y: -200)
            }
        }
    }
}

extension View {
    func onboardingScreen() -> some View {
        preferredColorScheme(.dark)
    }

    func onboardingStepEntrance(_ active: Bool, delay: Double = 0) -> some View {
        opacity(active ? 1 : 0)
            .offset(y: active ? 0 : 22)
            .scaleEffect(active ? 1 : 0.97)
            .animation(OnboardingMotion.springPremium.delay(delay), value: active)
    }
}

// MARK: - Progress pills

struct OnboardingProgressBar: View {
    let filledSegments: Int
    let totalSegments: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSegments, id: \.self) { segment in
                OnboardingProgressPill(
                    isFilled: segment <= filledSegments,
                    isActive: segment == filledSegments && filledSegments > 0
                )
                .frame(maxWidth: .infinity)
            }
        }
        .animation(OnboardingMotion.springSnappy, value: filledSegments)
        .allowsHitTesting(false)
    }
}

private struct OnboardingProgressPill: View {
    let isFilled: Bool
    let isActive: Bool

    var body: some View {
        Capsule()
            .fill(
                isFilled
                    ? AnyShapeStyle(OnboardingTheme.accentGradient)
                    : AnyShapeStyle(Color.white.opacity(0.07))
            )
            .frame(height: 8)
            .shadow(
                color: isFilled && isActive ? OnboardingTheme.accentRed.opacity(0.22) : .clear,
                radius: 6,
                x: 0,
                y: 1
            )
    }
}

// MARK: - Typographie

struct OnboardingStepHeader: View {
    let segment: Int
    let title: String
    let subtitle: String
    @Environment(\.onboardingLayoutMetrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.isCompactHeight ? 10 : 14) {
            Text("ÉTAPE \(segment) · \(OnboardingFlowModel.progressSegmentCount)")
                .font(.system(size: 11, weight: .bold, design: .default))
                .tracking(1.2)
                .foregroundStyle(OnboardingTheme.warmGray)

            Text(title)
                .font(.system(size: metrics.stepTitleSize, weight: .bold, design: .default))
                .foregroundStyle(OnboardingTheme.offWhite)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: metrics.stepSubtitleSize, weight: .regular, design: .default))
                .foregroundStyle(OnboardingTheme.warmGray)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, metrics.horizontalPadding)
    }
}

// MARK: - Boutons

struct OnboardingPrimaryButton: View {
    let title: String
    var icon: String? = "arrow.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(OnboardingTheme.offWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(OnboardingTheme.accentGradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }
            }
            .shadow(color: OnboardingTheme.accentRed.opacity(0.28), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(OnboardingSpringButtonStyle())
    }
}

struct OnboardingSecondaryTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OnboardingTheme.warmGray)
                .padding(.vertical, 12)
        }
        .buttonStyle(OnboardingSpringButtonStyle())
    }
}

struct OnboardingSpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(OnboardingMotion.springSnappy, value: configuration.isPressed)
    }
}

/// Compat Share Extension + onboarding legacy.
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        OnboardingSpringButtonStyle().makeBody(configuration: configuration)
    }
}

// MARK: - Carte verre

struct OnboardingGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(OnboardingTheme.cardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.05),
                                        .clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(OnboardingTheme.cardStroke, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 10)
    }
}

// MARK: - Image loading

struct OnboardingImageSkeleton: View {
    var body: some View {
        LinearGradient(
            colors: [OnboardingTheme.skeletonTop, OnboardingTheme.skeletonBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct OnboardingImageFallback: View {
    var body: some View {
        ZStack {
            OnboardingImageSkeleton()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 26, weight: .ultraLight))
                .foregroundStyle(OnboardingTheme.warmGrayMuted.opacity(0.45))
        }
    }
}

// MARK: - Chrome retour

struct OnboardingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OnboardingTheme.offWhite)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(OnboardingTheme.cardFill)
                }
                .overlay {
                    Circle().stroke(OnboardingTheme.cardStroke, lineWidth: 1)
                }
        }
        .buttonStyle(OnboardingSpringButtonStyle())
        .accessibilityLabel(Text(String(localized: "Retour")))
    }
}
