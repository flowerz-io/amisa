//
//  SettingsView.swift
//  Balibu
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var providerSettings = ProviderSettingsStore.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    notificationSettingsPlaceholder
                } label: {
                    Label(String(localized: "Notifications"), systemImage: "bell.badge")
                }
            } header: {
                Text(String(localized: "Général"))
            }

            Section {
                NavigationLink {
                    aboutPlaceholder
                } label: {
                    Label(String(localized: "À propos"), systemImage: "info.circle")
                }
            }

            Section {
                NavigationLink {
                    howItWorksDetail
                } label: {
                    Label(String(localized: "Comment ça marche"), systemImage: "questionmark.circle")
                }
            } header: {
                Text(String(localized: "Aide"))
            }

            Section {
                ForEach(ProviderCatalog.all) { provider in
                    providerRow(provider)
                }
            } header: {
                Text(String(localized: "Providers"))
            } footer: {
                Text(String(localized: "Ces interrupteurs contrôlent les providers réellement exécutés côté backend."))
            }

            Section {
                HStack {
                    Text(String(localized: "Version"))
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(String(localized: "Build"))
                    Spacer()
                    Text(build)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(String(localized: "Application"))
            }
        }
        .navigationTitle(String(localized: "Réglages"))
        .navigationBarTitleDisplayMode(.large)
    }

    private func providerRow(_ provider: ProviderMetadata) -> some View {
        HStack(spacing: DesignTokens.spacingS) {
            ProviderLogoView(
                source: provider.logoSourceName,
                fallbackLabel: provider.displayName,
                logoHeight: 18,
                logoMaxWidth: 72
            )
            .frame(width: 72, alignment: .leading)

            Text(provider.displayName)
                .font(DesignTokens.bodyFont)

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
    }

    private var notificationSettingsPlaceholder: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text(String(localized: "Les préférences de notification se gèrent dans l’accueil et dans Réglages système."))
                .font(DesignTokens.bodyFont)
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer()
        }
        .padding(DesignTokens.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignTokens.backgroundColor)
        .navigationTitle(String(localized: "Notifications"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var aboutPlaceholder: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text("Balibu")
                .font(DesignTokens.titleFont)
            Text(String(localized: "Trouve des pièces similaires sur les marketplaces à partir d’une image."))
                .font(DesignTokens.bodyFont)
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer()
        }
        .padding(DesignTokens.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignTokens.backgroundColor)
        .navigationTitle(String(localized: "À propos"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var howItWorksDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingL) {
                Text(String(localized: "Trois étapes"))
                    .font(DesignTokens.headlineFont)
                    .foregroundStyle(DesignTokens.textPrimary)

                VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
                    howItWorksStep(number: 1, text: String(localized: "Repère une pièce dans une app ou sur le web."))
                    howItWorksStep(number: 2, text: String(localized: "Partage vers Balibu ou importe une photo depuis l’accueil."))
                    howItWorksStep(number: 3, text: String(localized: "Balibu analyse l’image et propose des annonces similaires sur les marketplaces activées. Tu peux aussi lancer une recherche directement par mot-clé."))
                }
                .padding(DesignTokens.spacingM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM, style: .continuous))
            }
            .padding(DesignTokens.spacingL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignTokens.backgroundColor)
        .navigationTitle(String(localized: "Comment ça marche"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func howItWorksStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingM) {
            Text("\(number)")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
                .frame(width: 22, height: 22, alignment: .center)
                .background(DesignTokens.accentMuted)
                .clipShape(Circle())

            Text(text)
                .font(DesignTokens.bodyFont)
                .foregroundStyle(DesignTokens.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
