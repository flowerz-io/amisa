//
//  LoadingView.swift
//  Balibu
//
//  Chargement analyse : barre de progression + logos providers.
//

import SwiftUI

/// Bloc réutilisable : animation providers + barre + texte.
struct LoadingProgressBlock: View {
    let message: String
    @State private var progress: CGFloat = 0
    @State private var progressTimer: Timer?

    var body: some View {
        VStack(spacing: DesignTokens.spacingM) {
            ProviderLoadingAnimationView()

            progressBar

            Text(message)
                .font(DesignTokens.bodyFont)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, DesignTokens.spacingS)
        .padding(.horizontal, DesignTokens.spacingS)
        .frame(maxWidth: .infinity)
        .onAppear { startProgressSimulation() }
        .onDisappear { progressTimer?.invalidate(); progressTimer = nil }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let width = max(0, geo.size.width * progress)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AmisaSemanticColors.progressTrackFill())
                    .frame(height: 8)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: width, height: 8)
            }
        }
        .frame(height: 8)
        .animation(.easeInOut(duration: 0.2), value: progress)
        .accessibilityLabel(message)
    }

    private func startProgressSimulation() {
        progress = 0.04
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.045, repeats: true) { _ in
            if progress < 0.92 {
                progress = min(0.92, progress + 0.01 + (0.92 - progress) * 0.004)
            }
        }
    }
}

struct AnalysisLoadingView: View {
    var message: String = String(localized: "Recherche des annonces similaires…")

    var body: some View {
        LoadingProgressBlock(message: message)
    }
}

typealias ProviderLoadingAnimationView = ProviderLoadingLogosView

/// Compatibilité : ancien nom utilisé dans les call sites.
typealias LoadingView = AnalysisLoadingView

#Preview {
    AnalysisLoadingView()
        .padding()
        .background(Color(.systemBackground))
}
