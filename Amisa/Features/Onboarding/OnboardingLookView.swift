//
//  OnboardingLookView.swift
//  Amisa
//

import SwiftUI

struct OnboardingLookView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 16)

                OnboardingStepHeader(
                    segment: 4,
                    title: "Choisis un look\nà analyser",
                    subtitle: "Amisa va retrouver les pièces similaires pour toi."
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                Spacer(minLength: 24)

                lookGrid
                    .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.08)) {
                appeared = true
            }
        }
    }

    private var lookGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(model.demoLooks) { look in
                Button {
                    model.selectLook(look)
                } label: {
                    LookCardView(look: look)
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appeared)
    }
}

struct LookCardView: View {
    let look: DemoLook

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            OnboardingAssetImageView(imageName: look.imageName)
                .frame(height: 170)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(look.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text(look.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}
