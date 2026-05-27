//
//  OnboardingFakeAnalysisView.swift
//  Amisa
//
//  Timer 1.5s unique — puis `completeFakeAnalysis()`.
//

import SwiftUI

struct OnboardingFakeAnalysisView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var scanOffset: CGFloat = -120

    private var look: DemoLook? { model.selectedLook }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 32)

                if let look {
                    analysisCard(look: look)
                        .frame(width: 260, height: 300)
                } else {
                    ProgressView()
                }

                VStack(spacing: 6) {
                    Text("Analyse en cours…")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Identification de la pièce principale")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 28)

                Spacer()
            }
        }
        .task(id: look?.id) {
            guard look != nil else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                scanOffset = 120
            }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            model.completeFakeAnalysis()
        }
    }

    private func analysisCard(look: DemoLook) -> some View {
        ZStack {
            OnboardingAssetImageView(imageName: look.imageName)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.45)],
                startPoint: .center,
                endPoint: .bottom
            )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.accentColor.opacity(0.85), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .blur(radius: 1)
                .offset(x: scanOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}
