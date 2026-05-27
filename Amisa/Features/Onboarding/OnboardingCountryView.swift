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
    @State private var appeared = false
    @State private var selection = CountryOption(id: "France", flag: "🇫🇷", name: "France")

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
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 16)

                OnboardingStepHeader(
                    segment: 2,
                    title: "Depuis quelle zone\nfais-tu tes achats ?",
                    subtitle: "On adapte la devise et les résultats Vinted selon ta zone."
                )
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 12)

                Picker("Zone", selection: $selection) {
                    ForEach(countries) { country in
                        Text("\(country.flag)  \(country.name)")
                            .font(.system(size: 22, weight: .medium))
                            .tag(country)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 280)

                Spacer()

                Button {
                    model.selectCountry(selection.name)
                } label: {
                    HStack(spacing: 8) {
                        Text("Continuer")
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(BouncyButtonStyle())
                .padding(.horizontal, 24)

                Button {
                    model.selectCountry("")
                } label: {
                    Text("Passer cette étape")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 32)
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            if let saved = model.selectedCountry,
               let match = countries.first(where: { $0.name == saved }) {
                selection = match
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.06)) {
                appeared = true
            }
        }
    }
}
