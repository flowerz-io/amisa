//
//  OnboardingPaywallView.swift
//  Balibu
//
//  Paywall premium — tout visible sans scroll.
//

import SwiftUI

// MARK: - Feature item

private struct PaywallFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
}

private let paywallFeatures: [PaywallFeature] = [
    PaywallFeature(icon: "magnifyingglass.circle.fill", iconColor: Color.accentColor, title: "Analyses illimitées",          subtitle: "Scanne autant de looks que tu veux"),
    PaywallFeature(icon: "storefront.fill",             iconColor: BrandColors.secondaryOrange, title: "Recherche Vinted", subtitle: "Annonces Vinted triées à partir de ton image ou de ta requête"),
    PaywallFeature(icon: "bolt.fill",                   iconColor: Color.yellow,      title: "Résultats plus rapides",       subtitle: "Priorité dans la file d'analyse"),
    PaywallFeature(icon: "bell.badge.fill",             iconColor: BrandColors.secondary, title: "Alertes meilleures offres",    subtitle: "Notifié dès qu'un prix baisse"),
    PaywallFeature(icon: "heart.fill",                  iconColor: Color.pink,        title: "Favoris & moodboards",         subtitle: "Sauvegarde tes pièces préférées"),
]

// MARK: - Main view

struct OnboardingPaywallView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            paywallBackground

            VStack(spacing: 0) {
                Spacer(minLength: 48)

                headerSection
                    .padding(.horizontal, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Spacer(minLength: 16).frame(maxHeight: 32)

                featuresSection
                    .padding(.horizontal, 20)

                Spacer(minLength: 16).frame(maxHeight: 24)

                pricingBadge
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer(minLength: 14).frame(maxHeight: 20)

                ctaSection
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: 20)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.82).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Background

    private var paywallBackground: some View {
        ZStack {
            LinearGradient(
                colors: BrandColors.editorialDarkBackground,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 400)
                .blur(radius: 90)
                .offset(x: 60, y: -200)

            Circle()
                .fill(BrandColors.secondaryOrange.opacity(0.12))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: -80, y: 300)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("🔓")
                .font(.system(size: 40))
                .phaseAnimator([false, true]) { view, up in
                    view.scaleEffect(up ? 1.10 : 1.0)
                        .rotationEffect(.degrees(up ? 4 : 0))
                } animation: { _ in .spring(response: 0.5, dampingFraction: 0.55) }

            Text("Débloque tes résultats")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Essai gratuit de 3 jours. Annulable à tout moment.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.60))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 7) {
            ForEach(Array(paywallFeatures.enumerated()), id: \.element.id) { idx, feature in
                FeatureRow(feature: feature)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 28)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.76)
                            .delay(Double(idx) * 0.055 + 0.22),
                        value: appeared
                    )
            }
        }
    }

    // MARK: - Pricing badge

    private var pricingBadge: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("3 jours gratuits")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    Text("OFFERTS")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.18))
                        .clipShape(Capsule())
                }

                Text("puis 7,99 € / mois")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.50))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("7,99 €")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text("/ mois")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.48))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 10) {
            // Primary CTA with shimmer — toujours visible
            Button {
                model.complete()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor)

                    ShimmerOverlay()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Essayer gratuitement 3 jours")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .shadow(color: Color.accentColor.opacity(0.45), radius: 16, x: 0, y: 6)
            }
            .buttonStyle(BouncyButtonStyle())

            // Secondary CTA
            Button {
                model.complete()
            } label: {
                Text("Continuer avec la version gratuite")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.40))
            }

            // Legal
            Text("Sans engagement. Annulable depuis les réglages App Store.")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.25))
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
    }
}

// MARK: - Feature row (compact)

private struct FeatureRow: View {
    let feature: PaywallFeature

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(feature.iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: feature.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(feature.iconColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(feature.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Text(feature.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.48))
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.green.opacity(0.70))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Shimmer effect

private struct ShimmerOverlay: View {
    @State private var phase: CGFloat = -200

    var body: some View {
        GeometryReader { _ in
            LinearGradient(
                colors: [.clear, .white.opacity(0.16), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 80)
            .offset(x: phase)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                phase = 400
            }
        }
    }
}
