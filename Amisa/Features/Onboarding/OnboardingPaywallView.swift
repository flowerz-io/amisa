//
//  OnboardingPaywallView.swift
//  Amisa
//

import SwiftUI

private struct PaywallBenefit: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

private let paywallBenefits: [PaywallBenefit] = [
    PaywallBenefit(
        icon: "infinity",
        title: "Analyses illimitées",
        subtitle: "Scanne autant de vêtements que tu veux"
    ),
    PaywallBenefit(
        icon: "bell.badge.fill",
        title: "Alertes instantanées",
        subtitle: "Sois alerté dès qu'une nouvelle annonce correspond à tes recherches enregistrées"
    ),
]

struct OnboardingPaywallView: View {
    @ObservedObject var model: OnboardingFlowModel
    @Environment(\.onboardingLayoutMetrics) private var metrics
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepScroll {
                VStack(spacing: metrics.isCompactHeight ? 14 : 20) {
                    paywallHero
                        .onboardingStepEntrance(appeared)

                    freeTierBadge
                        .padding(.horizontal, metrics.horizontalPadding)
                        .onboardingStepEntrance(appeared, delay: 0.04)

                    benefitsList
                        .padding(.top, 4)
                        .onboardingStepEntrance(appeared, delay: 0.08)

                    pricingCard
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.isCompactHeight ? 16 : 22)
                        .onboardingStepEntrance(appeared, delay: 0.16)
                }
                .padding(.top, 4)
            }

            OnboardingPinnedFooter {
                ctaBlock
                    .onboardingStepEntrance(appeared, delay: 0.2)
            }
        }
        .onAppear {
            withAnimation(OnboardingMotion.springPremium.delay(0.06)) {
                appeared = true
            }
        }
    }

    private var paywallHero: some View {
        ZStack {
            Circle()
                .fill(OnboardingTheme.accentRed.opacity(0.07))
                .frame(width: metrics.isCompactHeight ? 140 : 180)
                .blur(radius: 40)
                .offset(y: -12)

            VStack(spacing: metrics.isCompactHeight ? 8 : 10) {
                Text("PREMIUM")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(OnboardingTheme.accentRed)

                Text("Analyses sans limite")
                    .font(.system(size: metrics.paywallHeroTitleSize, weight: .bold))
                    .foregroundStyle(OnboardingTheme.offWhite)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Passe à Premium pour scanner à volonté et recevoir des alertes sur tes recherches enregistrées.")
                    .font(.system(size: metrics.isCompactHeight ? 13 : 14))
                    .foregroundStyle(OnboardingTheme.warmGray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, metrics.horizontalPadding + 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var freeTierBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "5.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(OnboardingTheme.warmGray)

            VStack(alignment: .leading, spacing: 2) {
                Text("Version gratuite")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.offWhite)
                Text("5 analyses par mois")
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingTheme.warmGray)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(OnboardingTheme.cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(OnboardingTheme.cardStroke, lineWidth: 1)
                }
        }
    }

    private var benefitsList: some View {
        VStack(spacing: metrics.paywallBenefitSpacing) {
            ForEach(Array(paywallBenefits.enumerated()), id: \.element.id) { index, benefit in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: benefit.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.accentRed)
                        .frame(width: 30, height: 30)
                        .background {
                            Circle()
                                .fill(OnboardingTheme.accentRed.opacity(0.12))
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(benefit.title)
                            .font(.system(size: metrics.isCompactHeight ? 13 : 14, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.offWhite)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(benefit.subtitle)
                            .font(.system(size: metrics.isCompactHeight ? 11 : 12))
                            .foregroundStyle(OnboardingTheme.warmGray)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(OnboardingTheme.accentRed.opacity(0.8))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, metrics.isCompactHeight ? 10 : 12)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(OnboardingTheme.cardFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(OnboardingTheme.cardStroke, lineWidth: 1)
                        }
                }
                .onboardingStaggeredEntrance(appeared, index: index + 3, baseDelay: 0.14)
            }
        }
        .padding(.horizontal, metrics.horizontalPadding)
    }

    private var pricingCard: some View {
        OnboardingGlassCard(cornerRadius: 20) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Premium")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(OnboardingTheme.offWhite)
                    Text("3 jours gratuits, puis")
                        .font(.system(size: 11))
                        .foregroundStyle(OnboardingTheme.warmGray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("7,99 €")
                        .font(.system(size: metrics.isCompactHeight ? 22 : 24, weight: .bold))
                        .foregroundStyle(OnboardingTheme.offWhite)
                    Text("/ mois")
                        .font(.system(size: 11))
                        .foregroundStyle(OnboardingTheme.warmGray)
                }
            }
            .padding(metrics.isCompactHeight ? 14 : 16)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(OnboardingTheme.accentRed.opacity(0.4), lineWidth: 1)
        }
    }

    private var ctaBlock: some View {
        VStack(spacing: metrics.isCompactHeight ? 8 : 10) {
            OnboardingPrimaryButton(title: String(localized: "Essayer gratuitement 3 jours")) {
                model.completeOnboarding()
            }

            Button {
                model.completeOnboarding()
            } label: {
                Text("Continuer avec la version gratuite")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OnboardingTheme.warmGray)
            }
            .buttonStyle(.plain)

            Text("Sans engagement. Annulable depuis les réglages App Store.")
                .font(.system(size: 10))
                .foregroundStyle(OnboardingTheme.warmGrayMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
    }
}
