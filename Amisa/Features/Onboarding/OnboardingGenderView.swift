//
//  OnboardingGenderView.swift
//  Amisa
//

import SwiftUI

struct OnboardingGenderView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false

    private let options: [(id: String, label: String, icon: String, colors: [Color])] = [
        ("Femme", "Femme", "figure.stand.dress", [
            Color(red: 0.95, green: 0.78, blue: 0.82),
            Color(red: 0.86, green: 0.42, blue: 0.55),
        ]),
        ("Homme", "Homme", "figure.stand", [
            Color(red: 0.26, green: 0.17, blue: 0.14),
            Color(red: 0.50, green: 0.30, blue: 0.20),
        ]),
    ]

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 16)

                OnboardingStepHeader(
                    segment: 1,
                    title: "Tu recherches\nprincipalement pour :",
                    subtitle: "On adapte les résultats, les tailles et les suggestions."
                )
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 28)

                HStack(spacing: 12) {
                    ForEach(options, id: \.id) { option in
                        genderCard(option)
                    }
                }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.06)) {
                appeared = true
            }
        }
    }

    private func genderCard(_ option: (id: String, label: String, icon: String, colors: [Color])) -> some View {
        let isSelected = model.selectedGender == option.id

        return Button {
            model.selectGender(option.id)
        } label: {
            ZStack {
                LinearGradient(
                    colors: isSelected ? option.colors : [
                        Color(uiColor: .secondarySystemGroupedBackground),
                        Color(uiColor: .secondarySystemGroupedBackground),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: option.icon)
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(isSelected ? .white : .primary.opacity(0.65))
                    Text(option.label)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .primary)
                    Spacer(minLength: 36)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color(uiColor: .separator), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
