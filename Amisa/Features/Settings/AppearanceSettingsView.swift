//
//  AppearanceSettingsView.swift
//  Balibu
//
//  Thème (Système / Clair / Sombre) et icône d'application.
//

import SwiftUI

// MARK: - AppColorScheme

enum AppColorScheme: Int, CaseIterable {
    case system = 0
    case light  = 1
    case dark   = 2

    var label: String {
        switch self {
        case .system: return "Système"
        case .light:  return "Clair"
        case .dark:   return "Sombre"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - AppIconOption

struct AppIconOption: Identifiable {
    let id: String?         // nil = icône par défaut
    let displayName: String
    let assetName: String?  // asset dans xcassets; nil = icône app principale

    static let all: [AppIconOption] = [
        AppIconOption(id: nil,       displayName: "Amisa",      assetName: nil),
        // TODO: Ajouter les icônes alternatives déclarées dans Info.plist
        // et dans Assets.xcassets > AppIcon (Alternate App Icons).
        // Exemple :
        // AppIconOption(id: "AppIconDark",  displayName: "Dark",   assetName: "AppIconDark"),
        // AppIconOption(id: "AppIconLight", displayName: "Light",  assetName: "AppIconLight"),
    ]
}

// MARK: - AppearanceSettingsView

struct AppearanceSettingsView: View {
    @AppStorage("amisa.colorScheme") private var colorSchemeRaw: Int = 0

    private var currentScheme: AppColorScheme {
        AppColorScheme(rawValue: colorSchemeRaw) ?? .system
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                themeSection
                appIconSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Apparence")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(currentScheme.colorScheme)
    }

    // MARK: - Thème

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THÈME")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            HStack(spacing: 10) {
                ForEach(AppColorScheme.allCases, id: \.rawValue) { scheme in
                    themeCard(scheme)
                }
            }
        }
    }

    private func themeCard(_ scheme: AppColorScheme) -> some View {
        let selected = colorSchemeRaw == scheme.rawValue
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                colorSchemeRaw = scheme.rawValue
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: scheme.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)

                Text(scheme.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? Color.accentColor : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color.accentColor : Color.primary.opacity(0.06), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Icône app

    private var appIconSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ICÔNE DE L'APPLICATION")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AppIconOption.all) { option in
                    iconOptionCell(option)
                }
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text("Des icônes alternatives seront disponibles dans une prochaine mise à jour.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }

    private func iconOptionCell(_ option: AppIconOption) -> some View {
        let isCurrent = UIApplication.shared.alternateIconName == option.id

        return Button {
            UIApplication.shared.setAlternateIconName(option.id) { error in
                // Silently ignore — icônes alternatives peut-être pas encore déclarées dans Info.plist
                if let error { print("[AppIcon] \(error.localizedDescription)") }
            }
        } label: {
            VStack(spacing: 8) {
                // Aperçu icône
                Group {
                    if let assetName = option.assetName, UIImage(named: assetName) != nil {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        // Fallback : affiche l'AppIcon principal
                        Image("AppIcon")
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isCurrent ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isCurrent ? 2 : 1)
                )

                Text(option.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
}
