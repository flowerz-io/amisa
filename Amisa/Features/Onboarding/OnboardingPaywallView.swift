//
//  OnboardingPaywallView.swift
//  Amisa
//

import SwiftUI

struct OnboardingPaywallView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: BrandColors.editorialDarkBackground,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 56)

                VStack(spacing: 10) {
                    Text("Passe en Premium")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Analyses illimitées, alertes prix et favoris.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 28)

                pricingBadge
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        model.completeOnboarding()
                    } label: {
                        Text("Essayer gratuitement 3 jours")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(BouncyButtonStyle())

                    Button {
                        model.completeOnboarding()
                    } label: {
                        Text("Continuer avec la version gratuite")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.08)) {
                appeared = true
            }
        }
    }

    private var pricingBadge: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Premium")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("3 jours gratuits")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Spacer()
            Text("7,99 € / mois")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
