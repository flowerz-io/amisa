//
//  ShareExtensionAnalysisLoading.swift
//  BalibuShareExtension
//
//  Bloc de chargement aligné sur l’app native (logos + barre + texte).
//

import SwiftUI
import UIKit

private struct ShareExtensionProviderLogoView: View {
    let provider: ShareExtensionProviderID
    let logoHeight: CGFloat
    let logoMaxWidth: CGFloat

    var body: some View {
        if let ui = UIImage(named: provider.assetName) {
            Image(uiImage: ui)
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(height: logoHeight, alignment: .center)
                .frame(maxWidth: logoMaxWidth, alignment: .trailing)
                .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)
                .fixedSize(horizontal: true, vertical: true)
        } else {
            Text(provider.displayName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: true, vertical: true)
        }
    }
}

private struct ShareExtensionProviderLogoAnimation: View {
    @State private var activeIndex = 0
    @State private var singleLogoPulse = false
    @State private var cycleTask: Task<Void, Never>?

    private var providers: [ShareExtensionProviderID] {
        ShareExtensionProviderID.allCases.filter(\.isEnabledInSettings)
    }

    var body: some View {
        Group {
            if providers.isEmpty {
                Color.clear.frame(height: 36)
            } else {
                HStack(spacing: 16) {
                    ForEach(Array(providers.enumerated()), id: \.offset) { offset, provider in
                        let isActive = providers.count == 1
                            ? singleLogoPulse
                            : offset == activeIndex
                        ShareExtensionProviderLogoView(
                            provider: provider,
                            logoHeight: 28,
                            logoMaxWidth: 80
                        )
                        .opacity(providers.count == 1 ? 1 : (isActive ? 1 : 0.4))
                        .offset(y: isActive ? -15 : 0)
                        .rotationEffect(.degrees(isActive ? 12 : 0))
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.78),
                            value: isActive
                        )
                    }
                }
                .frame(minHeight: 36)
            }
        }
        .onAppear { startCycle() }
        .onDisappear { stopCycle() }
    }

    private func startCycle() {
        stopCycle()
        let list = providers
        guard !list.isEmpty else { return }
        if list.count == 1 {
            cycleTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 850_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                        singleLogoPulse.toggle()
                    }
                }
            }
            return
        }
        cycleTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 850_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    activeIndex = (activeIndex + 1) % list.count
                }
            }
        }
    }

    private func stopCycle() {
        cycleTask?.cancel()
        cycleTask = nil
    }
}

struct ShareExtensionAnalysisLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ShareExtensionProviderLogoAnimation()

            Text(String(localized: "Recherche des annonces similaires…"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }
}
