//
//  ProviderLoadingLogosView.swift
//  Balibu
//
//  Animation séquentielle des logos des providers activés (chargement analyse).
//

import SwiftUI

struct ProviderLoadingLogosView: View {
    @ObservedObject private var providerSettings = ProviderSettingsStore.shared
    @State private var activeIndex = 0
    @State private var singleLogoPulse = false
    @State private var cycleTask: Task<Void, Never>?

    private var providers: [ProviderMetadata] {
        ProviderCatalog.all.filter { providerSettings.isEnabled($0.id) }
    }

    var body: some View {
        Group {
            if providers.isEmpty {
                Color.clear.frame(height: 36)
            } else {
                HStack(spacing: DesignTokens.spacingM) {
                    ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                        let isActive = providers.count == 1
                            ? singleLogoPulse
                            : index == activeIndex
                        ProviderLogoView(
                            source: provider.logoSourceName,
                            fallbackLabel: provider.displayName,
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
        .onChange(of: providers.count) { _, _ in
            activeIndex = 0
        }
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
