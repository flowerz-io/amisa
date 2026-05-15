//
//  ProvidersSettingsView.swift
//  Balibu
//
//  Sous-page Réglages → Préférences → Providers.
//  Gère les toggles provider et affiche leur statut runtime.
//

import SwiftUI

struct ProvidersSettingsView: View {
    @StateObject private var providerSettings = ProviderSettingsStore.shared
    @ObservedObject private var runtimeAvailability = ProviderRuntimeAvailabilityStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Explication
                Text("Ces réglages contrôlent les marketplaces interrogées lors de tes analyses. Désactive un provider pour l'exclure des résultats.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                // Carte toggles
                VStack(spacing: 0) {
                    ForEach(Array(ProviderCatalog.all.enumerated()), id: \.element.id) { index, provider in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 60)
                        }
                        providerRow(provider)
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Providers")
        .navigationBarTitleDisplayMode(.large)
    }

    private func providerRow(_ provider: ProviderMetadata) -> some View {
        let ebayBlocked = provider.id == .ebay && runtimeAvailability.ebay?.status == .blocked_by_challenge

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                ProviderLogoView(
                    source: provider.logoSourceName,
                    fallbackLabel: provider.displayName,
                    logoHeight: 18,
                    logoMaxWidth: 72
                )
                .frame(width: 72, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)

                    if ebayBlocked {
                        Text("Indisponible temporairement")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignTokens.error)
                    }
                }

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { providerSettings.isEnabled(provider.id) },
                        set: { providerSettings.setEnabled($0, for: provider.id) }
                    )
                )
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
        }
    }
}

#Preview {
    NavigationStack {
        ProvidersSettingsView()
    }
}
