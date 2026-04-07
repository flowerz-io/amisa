//
//  ResultsFiltersPagerSheet.swift
//  Balibu
//

import SwiftUI

struct ResultsFiltersPagerSheet: View {
    @Binding var selectedTab: ResultsFilterTab
    @Binding var enabledProviderKeys: Set<String>
    let availableProviders: [String]
    /// Statut serveur (ex. eBay bloqué par challenge).
    let providerAvailability: ProviderAvailabilityMapDTO?
    /// Totaux backend par provider.
    let providerCounts: ProviderCountsDTO
    let countFormatter: (Int) -> String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $selectedTab) {
                marketplaceTab
                    .tag(ResultsFilterTab.marketplace)
                placeholderTab(
                    title: ResultsFilterTab.size.title,
                    description: String(localized: "Filtrage par taille — à brancher.")
                )
                .tag(ResultsFilterTab.size)
                placeholderTab(
                    title: ResultsFilterTab.brand.title,
                    description: String(localized: "Filtrage par marque — à brancher.")
                )
                .tag(ResultsFilterTab.brand)
                placeholderTab(
                    title: ResultsFilterTab.condition.title,
                    description: String(localized: "Filtrage par état — à brancher.")
                )
                .tag(ResultsFilterTab.condition)
                placeholderTab(
                    title: ResultsFilterTab.color.title,
                    description: String(localized: "Filtrage par couleur — à brancher.")
                )
                .tag(ResultsFilterTab.color)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .background(DesignTokens.background)
    }

    private var header: some View {
        HStack {
            Button(String(localized: "Fermer")) {
                onClose()
            }
            .font(DesignTokens.body)

            Spacer()

            Text(selectedTab.title)
                .font(DesignTokens.headline)
                .lineLimit(1)

            Spacer()

            Color.clear
                .frame(width: 52, height: 1)
        }
        .padding(.horizontal, DesignTokens.spacingM)
        .padding(.vertical, DesignTokens.spacingS)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(height: 0.5)
        }
    }

    private var marketplaceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                Text(String(localized: "Sources affichées"))
                    .font(DesignTokens.caption)
                    .foregroundStyle(.secondary)

                ForEach(availableProviders, id: \.self) { provider in
                    providerRow(source: provider)
                }
            }
            .padding(DesignTokens.spacingM)
        }
    }

    private func providerRow(source: String) -> some View {
        let label = MarketplaceSource.displayLabel(from: source)
        let key = MarketplaceSource.canonicalKey(from: source)
        let temporarilyUnavailable =
            key == "ebay" && providerAvailability?.ebay?.status == .blocked_by_challenge

        return HStack(alignment: .center, spacing: DesignTokens.spacingS) {
            ProviderLogoView(
                source: source,
                fallbackLabel: label,
                logoHeight: 20,
                logoMaxWidth: 72
            )
            .frame(width: 72, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.spacingXS) {
                    Text(label)
                        .font(DesignTokens.body)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Spacer(minLength: DesignTokens.spacingXS)
                    Text("(\(countFormatter(providerCounts.count(for: key) ?? 0)))")
                        .font(DesignTokens.body)
                        .foregroundStyle(.secondary)
                }
                if temporarilyUnavailable {
                    Text(String(localized: "Indisponible temporairement"))
                        .font(DesignTokens.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: DesignTokens.spacingS)

            Toggle("", isOn: Binding(
                get: { enabledProviderKeys.contains(key) },
                set: { enabled in
                    if temporarilyUnavailable { return }
                    if enabled {
                        enabledProviderKeys.insert(key)
                    } else {
                        enabledProviderKeys.remove(key)
                    }
                }
            ))
            .labelsHidden()
            .disabled(temporarilyUnavailable)
        }
        .padding(.vertical, DesignTokens.spacingXS)
    }

    private func placeholderTab(title: String, description: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
                Text(title)
                    .font(DesignTokens.headline)
                Text(description)
                    .font(DesignTokens.body)
                    .foregroundStyle(.secondary)
            }
            .padding(DesignTokens.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

