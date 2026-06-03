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
    PaywallBenefit(icon: "infinity", title: "Analyses illimitées", subtitle: "Scanne autant de looks que tu veux"),
    PaywallBenefit(icon: "bolt.fill", title: "Résultats plus rapides", subtitle: "Priorité dans la file d’analyse"),
    PaywallBenefit(icon: "bell.badge.fill", title: "Alertes instantanées", subtitle: "Sois le premier sur les bonnes affaires"),
    PaywallBenefit(icon: "sparkles", title: "Meilleures annonces", subtitle: "Tri premium sur Vinted"),
    PaywallBenefit(icon: "heart.fill", title: "Favoris & moodboards", subtitle: "Sauvegarde tes pièces préférées"),
]

struct OnboardingPaywallView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 760

            VStack(spacing: 0) {
                paywallHero(compact: compact)
                    .onboardingStepEntrance(appeared)

                benefitsList(compact: compact)
                    .padding(.top, compact ? 10 : 14)
                    .onboardingStepEntrance(appeared, delay: 0.08)

                pricingCard(compact: compact)
                    .padding(.horizontal, 24)
                    .padding(.top, compact ? 22 : 28)
                    .onboardingStepEntrance(appeared, delay: 0.16)

                Spacer(minLength: compact ? 6 : 10)

                ctaBlock(compact: compact)
                    .onboardingStepEntrance(appeared, delay: 0.2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            withAnimation(OnboardingMotion.springPremium.delay(0.06)) {
                appeared = true
            }
        }
    }

    private func paywallHero(compact: Bool) -> some View {
        ZStack {
            Circle()
                .fill(OnboardingTheme.accentRed.opacity(0.07))
                .frame(width: compact ? 160 : 180)
                .blur(radius: 40)
                .offset(y: -12)

            VStack(spacing: compact ? 8 : 10) {
                Text("CLUB PRIVÉ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(OnboardingTheme.accentRed)

                Text("Ton assistant\nfashion personnel")
                    .font(.system(size: compact ? 28 : 30, weight: .bold))
                    .foregroundStyle(OnboardingTheme.offWhite)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .lineLimit(2)

                Text("L’expérience complète Amisa — analyses, alertes et résultats premium.")
                    .font(.system(size: compact ? 13 : 14))
                    .foregroundStyle(OnboardingTheme.warmGray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 28)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
        }
        .padding(.top, 4)
    }

    private func benefitsList(compact: Bool) -> some View {
        VStack(spacing: compact ? 6 : 8) {
            ForEach(Array(paywallBenefits.enumerated()), id: \.element.id) { index, benefit in
                HStack(spacing: 12) {
                    Image(systemName: benefit.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.accentRed)
                        .frame(width: 30, height: 30)
                        .background {
                            Circle()
                                .fill(OnboardingTheme.accentRed.opacity(0.12))
                        }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(benefit.title)
                            .font(.system(size: compact ? 13 : 14, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.offWhite)
                            .lineLimit(1)
                        Text(benefit.subtitle)
                            .font(.system(size: compact ? 11 : 12))
                            .foregroundStyle(OnboardingTheme.warmGray)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(OnboardingTheme.accentRed.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, compact ? 8 : 9)
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
        .padding(.horizontal, 24)
    }

    private func pricingCard(compact: Bool) -> some View {
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
                        .font(.system(size: compact ? 22 : 24, weight: .bold))
                        .foregroundStyle(OnboardingTheme.offWhite)
                    Text("/ mois")
                        .font(.system(size: 11))
                        .foregroundStyle(OnboardingTheme.warmGray)
                }
            }
            .padding(compact ? 14 : 16)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(OnboardingTheme.accentRed.opacity(0.4), lineWidth: 1)
        }
    }

    private func ctaBlock(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 10) {
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
                .lineLimit(2)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}
