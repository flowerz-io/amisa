//
//  OnboardingCountryView.swift
//  Balibu
//
//  Étape 3 — sélection de la zone avec un picker wheel iOS premium.
//

import SwiftUI

struct OnboardingCountryView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false
    @State private var pickerSelection: OnboardingCountry = .france

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                OnboardingStepHeader(
                    currentStep: 2,
                    title: "Depuis quelle zone\nfais-tu tes achats ?",
                    subtitle: "On adapte la devise et les résultats Vinted disponibles selon ta zone."
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Spacer(minLength: 20)

                countryPicker
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.12), value: appeared)

                Spacer()

                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.2), value: appeared)

                skipButton
                    .padding(.bottom, 48)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.26), value: appeared)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Présélectionner le pays du model si déjà choisi
            if let existing = model.country {
                pickerSelection = existing
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.08)) {
                appeared = true
            }
        }
    }

    // MARK: - Picker wheel

    private var countryPicker: some View {
        Picker("Zone", selection: $pickerSelection) {
            ForEach(OnboardingCountry.allCases) { country in
                Text("\(country.flag)  \(country.displayName)")
                    .font(.system(size: 25, weight: .medium)) // +40%
                    .tag(country)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 308) // +40% (220 × 1.4)
        // Pas de fond / carré gris — picker natif nu
        .padding(.horizontal, 8)
    }

    // MARK: - Continuer

    private var continueButton: some View {
        Button {
            confirmSelection()
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
            .shadow(color: Color.accentColor.opacity(0.35), radius: 14, x: 0, y: 5)
        }
        .buttonStyle(BouncyButtonStyle())
    }

    // MARK: - Skip

    private var skipButton: some View {
        Button {
            model.userSkippedCountryStep()
        } label: {
            Text("Passer cette étape")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Action

    private func confirmSelection() {
        model.userCommittedCountry(pickerSelection)
    }
}
