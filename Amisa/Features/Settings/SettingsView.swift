//
//  SettingsView.swift
//  Amisa
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("amisa.hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showOnboarding = false
    @State private var showEditProfile = false
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // MARK: Compte
                lumaSection(String(localized: "Compte")) {
                    Button {
                        showEditProfile = true
                    } label: {
                        lumaRowContent(
                            icon: "person.crop.circle",
                            color: Color.accentColor,
                            label: String(localized: "Modifier le profil"),
                            trailing: .chevron
                        )
                    }
                    .buttonStyle(.plain)

                    lumaDivider()

                    lumaNavLink(icon: "person.crop.circle.fill", color: BrandColors.primaryRed, label: String(localized: "Paramètres du compte")) {
                        AccountSettingsView()
                    }
                    // Déconnexion
                    if AuthManager.shared.isAuthenticated {
                        lumaDivider()
                    lumaAction(icon: "rectangle.portrait.and.arrow.right", color: .red, label: "Se déconnecter", labelColor: .red) {
                            Task {
                                await AuthManager.shared.signOut()
                                dismiss()
                            }
                        }
                    }
                }

                // MARK: Préférences
                lumaSection("Préférences") {
                    lumaNavLink(icon: "bell.fill",              color: BrandColors.primary, label: "Notifications") { NotificationsSettingsView() }
                    lumaDivider()
                    lumaNavLink(icon: "circle.lefthalf.filled", color: .gray,   label: "Apparence")     { AppearanceSettingsView()    }
                    lumaDivider()
                    lumaNavLink(icon: "storefront.fill",        color: BrandColors.secondary, label: "Providers")      { ProvidersSettingsView()     }
                }

                // MARK: Ressources
                lumaSection("Ressources") {
                    lumaExternalLink(icon: "bubble.left.and.bubble.right.fill", color: .teal,
                                     label: "Contacter le support",
                                     url: "mailto:jonas@flowerz.io")
                    lumaDivider()
                    lumaExternalLink(icon: "star.fill", color: .yellow,
                                     label: "Évaluer sur l'App Store",
                                     // TODO: remplacer APP_ID quand l'app sera publiée
                                     url: "https://apps.apple.com/app/idAPP_ID?action=write-review")
                    lumaDivider()
                    lumaExternalLink(icon: "camera.fill",
                                     color: Color(red: 0.85, green: 0.2, blue: 0.5),
                                     label: "Amisa sur Instagram",
                                     url: "https://instagram.com/amisa.app",
                                     useAsset: "AmisaInstagramIcon")
                    lumaDivider()
                    lumaExternalLink(icon: "bird.fill", color: .black,
                                     label: "Amisa sur X",
                                     url: "https://x.com/amisa.app",
                                     useAsset: "AmisaXIcon")
                }

                // MARK: Application
                lumaSection("Application") {
                    lumaAction(icon: "sparkles", color: .purple, label: "Revoir l'introduction") {
                        showOnboarding = true
                    }
                    lumaDivider()
                    lumaNavLink(icon: "info.circle.fill", color: BrandColors.secondaryOrange, label: "À propos") { aboutPlaceholder }
                    lumaDivider()
                    lumaInfoRow(icon: "tag.fill",    color: .mint,  label: "Version", value: appVersion)
                    lumaDivider()
                    lumaInfoRow(icon: "hammer.fill", color: .brown, label: "Build",   value: build)
                }

            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingRootView {
                hasCompletedOnboarding = true
                showOnboarding = false
            }
        }
        .sheet(isPresented: $showEditProfile) {
            NavigationStack {
                EditProfileView()
            }
        }
    }

    // MARK: - Luma section

    private func lumaSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Row variants

    private func lumaNavLink<Destination: View>(
        icon: String, color: Color, label: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            lumaRowContent(icon: icon, color: color, label: label, trailing: .chevron)
        }
        .buttonStyle(.plain)
    }

    private func lumaAction(
        icon: String, color: Color, label: String, labelColor: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            lumaRowContent(icon: icon, color: color, label: label, labelColor: labelColor, trailing: .none)
        }
        .buttonStyle(.plain)
    }

    private func lumaExternalLink(
        icon: String, color: Color, label: String, url: String, useAsset: String? = nil
    ) -> some View {
        Button {
            if let u = URL(string: url) { UIApplication.shared.open(u) }
        } label: {
            lumaRowContent(icon: icon, color: color, label: label, trailing: .external, assetIcon: useAsset)
        }
        .buttonStyle(.plain)
    }

    private func lumaInfoRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            lumaSquircle(icon: icon, color: color)
            Text(label).font(.system(size: 16)).foregroundStyle(.primary)
            Spacer()
            Text(value).font(.system(size: 15)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private enum TrailingIcon { case chevron, external, none }

    private func lumaRowContent(
        icon: String, color: Color, label: String,
        labelColor: Color = .primary,
        trailing: TrailingIcon,
        assetIcon: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            if let asset = assetIcon, UIImage(named: asset) != nil {
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                lumaSquircle(icon: icon, color: color)
            }
            Text(label).font(.system(size: 16)).foregroundStyle(labelColor)
            Spacer()
            switch trailing {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            case .external:
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            case .none:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(Rectangle())
    }

    private func lumaSquircle(icon: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }

    private func lumaDivider() -> some View {
        Divider().padding(.leading, 56)
    }

    // MARK: - Inline destinations

    private var aboutPlaceholder: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text("Amisa").font(DesignTokens.titleFont)
            Text("Trouve des pièces similaires sur les marketplaces à partir d'une image.")
                .font(DesignTokens.bodyFont)
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer()
        }
        .padding(DesignTokens.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("À propos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
