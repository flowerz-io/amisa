//
//  SettingsView.swift
//  Balibu
//

import SwiftUI

struct SettingsView: View {
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
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
