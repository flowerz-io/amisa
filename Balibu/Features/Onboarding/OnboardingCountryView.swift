//
//  OnboardingCountryView.swift
//  Balibu
//
//  Étape 3 — sélection du pays avec pills glassmorphism en cascade.
//

import SwiftUI

struct OnboardingCountryView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 120)

                headerBlock
                    .padding(.horizontal, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Spacer(minLength: 20)

                countryGrid

                Spacer()

                skipButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 48)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.08)) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(spacing: 8) {
            Text("Depuis quelle zone\nfais-tu tes achats ?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("On adapte les marketplaces, les devises et les résultats disponibles chez toi.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Country grid

    private var countryGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ]

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(OnboardingCountry.allCases.enumerated()), id: \.element.id) { idx, country in
                countryPill(country, index: idx)
            }
        }
        .padding(.horizontal, 20)
    }

    private func countryPill(_ country: OnboardingCountry, index: Int) -> some View {
        let isSelected = model.country == country

        return Button {
            selectCountry(country)
        } label: {
            HStack(spacing: 10) {
                Text(country.flag)
                    .font(.title2)

                Text(country.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color(uiColor: .separator), lineWidth: 1)
            }
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.3) : .clear,
                radius: 12, x: 0, y: 4
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.75).delay(Double(index) * 0.07 + 0.2),
            value: appeared
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.70), value: isSelected)
    }

    // MARK: - Skip

    private var skipButton: some View {
        Button {
            model.advance()
        } label: {
            Text("Passer cette étape")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Action

    private func selectCountry(_ country: OnboardingCountry) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.70)) {
            model.country = country
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            model.advance()
        }
    }
}
