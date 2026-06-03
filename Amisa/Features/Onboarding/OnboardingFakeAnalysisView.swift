//
//  OnboardingFakeAnalysisView.swift
//  Amisa
//

import SwiftUI

struct OnboardingFakeAnalysisView: View {
    @ObservedObject var model: OnboardingFlowModel
    @State private var zoomScale: CGFloat = 1.04
    @State private var focusVisible = false
    @State private var scanProgress: CGFloat = 0
    @State private var pieceDetected = false
    @State private var statusOpacity: Double = 0
    @State private var focusBreathing: CGFloat = 1
    @State private var focusPulse: Double = 0.55

    private var look: DemoLook? { model.selectedLook }

    var body: some View {
        Group {
            if let look {
                GeometryReader { geo in
                    let preset = OnboardingAnalysisFocusPresets.preset(for: look.id)
                    let focusRect = AnalysisFocusLayout.focusRect(
                        imageName: look.imageName,
                        preset: preset,
                        containerSize: geo.size
                    )

                    ZStack {
                        OnboardingAssetImageView(imageName: look.imageName)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

                        Color.black.opacity(0.38)

                        AnalysisFocusOverlay(
                            containerSize: geo.size,
                            focusRect: focusRect,
                            isVisible: focusVisible,
                            scanProgress: scanProgress,
                            pulseOpacity: focusPulse,
                            breathingScale: focusBreathing
                        )

                        statusOverlay(
                            preset: preset,
                            focusRect: focusRect,
                            containerSize: geo.size
                        )
                    }
                    .scaleEffect(zoomScale)
                    .animation(.easeOut(duration: 1.1), value: zoomScale)
                }
            } else {
                ProgressView()
                    .tint(OnboardingTheme.accentRed)
            }
        }
        .onboardingScreen()
        .task(id: look?.id) {
            guard let look else { return }
            await runAnalysisSequence(look: look)
        }
    }

    private func statusOverlay(
        preset: FocusPreset,
        focusRect: CGRect,
        containerSize: CGSize
    ) -> some View {
        let textBlockHeight: CGFloat = pieceDetected ? 36 : 64
        let textCenterY = AnalysisStatusTextLayout.centerY(
            focusRect: focusRect,
            containerSize: containerSize,
            textBlockHeight: textBlockHeight
        )

        return VStack(spacing: 6) {
            if pieceDetected {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(preset.detectedLabel)
                        .font(.system(size: 22, weight: .bold))
                }
                .foregroundStyle(OnboardingTheme.accentRed)
            } else {
                Text("Analyse en cours…")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(OnboardingTheme.offWhite)
                Text("Détection de la pièce principale")
                    .font(.system(size: 15))
                    .foregroundStyle(OnboardingTheme.warmGray)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .position(x: containerSize.width / 2, y: textCenterY)
        .opacity(statusOpacity)
    }

    @MainActor
    private func runAnalysisSequence(look: DemoLook) async {
        zoomScale = 1.04
        focusVisible = false
        scanProgress = 0
        pieceDetected = false
        statusOpacity = 0
        focusBreathing = 1
        focusPulse = 0.55

        withAnimation(.easeOut(duration: 0.35)) {
            statusOpacity = 1
        }

        withAnimation(.easeOut(duration: 1.15)) {
            zoomScale = 1.1
        }

        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.5)) {
            focusVisible = true
        }

        withAnimation(.easeInOut(duration: 1.85).repeatForever(autoreverses: true)) {
            focusBreathing = 1.014
        }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            focusPulse = 0.92
        }

        let scanDuration: TimeInterval = 1.6
        let scanStart = Date()
        while Date().timeIntervalSince(scanStart) < scanDuration {
            guard !Task.isCancelled else { return }
            let elapsed = Date().timeIntervalSince(scanStart)
            scanProgress = CGFloat(min(1, elapsed / scanDuration))
            try? await Task.sleep(for: .milliseconds(32))
        }
        scanProgress = 1

        try? await Task.sleep(for: .milliseconds(280))
        guard !Task.isCancelled else { return }

        withAnimation(OnboardingMotion.springPremium) {
            pieceDetected = true
        }

        try? await Task.sleep(for: .milliseconds(900))
        guard !Task.isCancelled else { return }

        model.completeFakeAnalysis()
    }
}
