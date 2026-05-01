//
//  OnboardingPaywallView.swift
//  Balibu
//
//  Paywall premium — conversion vers abonnement.
//  Déclenché après la démo, moment psychologique clé.
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
    PaywallFeature(icon: "magnifyingglass.circle.fill",  iconColor: Color.accentColor,  title: "Analyses illimitées",              subtitle: "Scanne autant de looks que tu veux"),
    PaywallFeature(icon: "storefront.fill",              iconColor: Color.blue,          title: "Recherche multi-marketplaces",     subtitle: "Vinted, Grailed, eBay, Depop et plus"),
    PaywallFeature(icon: "bolt.fill",                    iconColor: Color.yellow,        title: "Résultats plus rapides",           subtitle: "Priorité dans la file d'analyse"),
    PaywallFeature(icon: "bell.badge.fill",              iconColor: Color.orange,        title: "Alertes meilleures offres",        subtitle: "Notifié dès qu'un prix baisse"),
    PaywallFeature(icon: "heart.fill",                   iconColor: Color.pink,          title: "Favoris & moodboards",             subtitle: "Sauvegarde tes pièces préférées"),
    PaywallFeature(icon: "tag.fill",                     iconColor: Color.green,         title: "Comparateur de prix",              subtitle: "Le meilleur deal en un coup d'œil"),
]

// MARK: - Main view

struct OnboardingPaywallView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false
    @State private var ctaPressed = false

    var body: some View {
        ZStack {
            paywallBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 72)

                    headerSection
                        .padding(.horizontal, 28)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)

                    Spacer(minLength: 28)

                    valuePropSection
                        .padding(.horizontal, 28)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)

                    Spacer(minLength: 20)

                    featuresSection
                        .padding(.horizontal, 20)

                    Spacer(minLength: 36)

                    pricingBadge
                        .padding(.horizontal, 28)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    Spacer(minLength: 24)

                    ctaSection
                        .padding(.horizontal, 24)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)

                    Spacer(minLength: 48)
                }
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
                colors: [
                    Color(red: 0.05, green: 0.03, blue: 0.10),
                    Color(red: 0.08, green: 0.05, blue: 0.15),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Glow accent
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 400)
                .blur(radius: 90)
                .offset(x: 60, y: -200)

            Circle()
                .fill(Color.purple.opacity(0.10))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: -80, y: 300)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("🔓")
                .font(.system(size: 48))
                .phaseAnimator([false, true]) { view, up in
                    view.scaleEffect(up ? 1.12 : 1.0)
                        .rotationEffect(.degrees(up ? 5 : 0))
                } animation: { _ in .spring(response: 0.5, dampingFraction: 0.55) }

            Text("Débloque tes résultats")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Essai gratuit de 3 jours. Annulable à tout moment.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    // MARK: - Value proposition

    private var valuePropSection: some View {
        Text("Retrouve les pièces avant qu'elles disparaissent des marketplaces.")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.80))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 10) {
            ForEach(Array(paywallFeatures.enumerated()), id: \.element.id) { idx, feature in
                FeatureRow(feature: feature)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 30)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.76)
                            .delay(Double(idx) * 0.06 + 0.25),
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    Text("OFFERTS")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.18))
                        .clipShape(Capsule())
                }

                Text("puis 7,99 € / mois")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("7,99 €")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("/ mois")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 12) {
            // Primary CTA with shimmer
            Button {
                model.complete()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor)

                    // Shimmer overlay
                    ShimmerOverlay()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Essayer gratuitement 3 jours")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .shadow(color: Color.accentColor.opacity(0.45), radius: 18, x: 0, y: 7)
            }
            .buttonStyle(BouncyButtonStyle())

            // Secondary CTA
            Button {
                model.complete()
            } label: {
                Text("Continuer avec la version gratuite")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
            }

            // Legal
            Text("Sans engagement. Annulable à tout moment depuis les réglages App Store.")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.28))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }
}

// MARK: - Feature row

private struct FeatureRow: View {
    let feature: PaywallFeature

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(feature.iconColor.opacity(0.15))
                    .frame(width: 42, height: 42)

                Image(systemName: feature.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(feature.iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(feature.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.green.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Shimmer effect

private struct ShimmerOverlay: View {
    @State private var phase: CGFloat = -200

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.18),
                    .clear,
                ],
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
