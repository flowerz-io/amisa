//
//  OnboardingCountryView.swift
//  Amisa
//

import SwiftUI

private struct CountryOption: Identifiable, Hashable {
    let id: String
    let flag: String
    let name: String
}

struct OnboardingCountryView: View {
    @ObservedObject var model: OnboardingFlowModel
    @Environment(\.onboardingLayoutMetrics) private var metrics
    @State private var appeared = false
    @State private var highlightedId: String?

    private let countries: [CountryOption] = [
        CountryOption(id: "France", flag: "🇫🇷", name: "France"),
        CountryOption(id: "Belgique", flag: "🇧🇪", name: "Belgique"),
        CountryOption(id: "Suisse", flag: "🇨🇭", name: "Suisse"),
        CountryOption(id: "Allemagne", flag: "🇩🇪", name: "Allemagne"),
        CountryOption(id: "Royaume-Uni", flag: "🇬🇧", name: "Royaume-Uni"),
        CountryOption(id: "Italie", flag: "🇮🇹", name: "Italie"),
        CountryOption(id: "Espagne", flag: "🇪🇸", name: "Espagne"),
        CountryOption(id: "Pays-Bas", flag: "🇳🇱", name: "Pays-Bas"),
        CountryOption(id: "Europe", flag: "🇪🇺", name: "Europe"),
        CountryOption(id: "États-Unis", flag: "🇺🇸", name: "États-Unis"),
        CountryOption(id: "Autre", flag: "🌍", name: "Autre"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepScroll {
                VStack(spacing: 16) {
                    OnboardingStepHeader(
                        segment: 2,
                        title: "Depuis quelle zone\nfais-tu tes achats ?",
                        subtitle: "On adapte la devise et les résultats Vinted selon ta zone."
                    )
                    .padding(.top, 8)
                    .onboardingStepEntrance(appeared)

                    LazyVStack(spacing: 10) {
                        ForEach(Array(countries.enumerated()), id: \.element.id) { index, country in
                            countryRow(country)
                                .onboardingStaggeredEntrance(appeared, index: index, baseDelay: 0.06)
                        }
                    }
                    .padding(.horizontal, metrics.horizontalPadding)
                }
            }

            OnboardingPinnedFooter {
                OnboardingSecondaryTextButton(title: String(localized: "Passer cette étape")) {
                    model.selectCountry("")
                }
                .onboardingStepEntrance(appeared, delay: 0.12)
            }
        }
        .onboardingScreen()
        .onAppear {
            withAnimation(OnboardingMotion.springPremium.delay(0.04)) {
                appeared = true
            }
        }
    }

    private func countryRow(_ country: CountryOption) -> some View {
        let isHighlighted = highlightedId == country.id

        return Button {
            highlightedId = country.id
            withAnimation(OnboardingMotion.springSnappy) {}
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                model.selectCountry(country.name)
            }
        } label: {
            HStack(spacing: 14) {
                Text(country.flag)
                    .font(.system(size: 26))
                    .frame(width: 36)

                Text(country.name)
                    .font(.system(size: 17, weight: isHighlighted ? .semibold : .medium))
                    .foregroundStyle(OnboardingTheme.offWhite)

                Spacer(minLength: 0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(OnboardingTheme.accentRed)
                    .opacity(isHighlighted ? 1 : 0)
                    .scaleEffect(isHighlighted ? 1 : 0.6)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isHighlighted ? OnboardingTheme.accentRed.opacity(0.14) : OnboardingTheme.cardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isHighlighted ? 0.08 : 0.04),
                                        .clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isHighlighted ? OnboardingTheme.accentRed.opacity(0.5) : OnboardingTheme.cardStroke,
                                lineWidth: isHighlighted ? 1.5 : 1
                            )
                    }
            }
            .onboardingSelectionGlow(isSelected: isHighlighted)
        }
        .buttonStyle(OnboardingSelectablePressStyle(isSelected: isHighlighted))
        .animation(OnboardingMotion.springSnappy, value: isHighlighted)
    }
}
