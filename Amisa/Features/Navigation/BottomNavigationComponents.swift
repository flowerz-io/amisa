import SwiftUI

struct BottomNavigationRow: View {
    @ObservedObject var router: Router
    var onScan: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            LeftTabCapsule(router: router)
                .frame(maxWidth: .infinity)

            ScanFloatingButton(action: onScan)

            RightTabCapsule(router: router)
                .frame(maxWidth: .infinity)
        }
        // Force la transparence des espaces entre les capsules
        .background(.clear)
    }
}

struct LeftTabCapsule: View {
    @ObservedObject var router: Router
    @ObservedObject private var iconStore = DynamicTabIconStore.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            homeTabItem
            tabItem(tab: .search, title: String(localized: "Recherche"), systemImage: "magnifyingglass")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background { LiquidGlassTabBarBackground() }
    }

    // MARK: - Onglet Home avec icône dynamique

    private var homeTabItem: some View {
        let isSelected = router.selectedTab == .home
        return Button {
            router.selectedTab = .home
        } label: {
            VStack(spacing: 4) {
                if let dynIcon = iconStore.homeIcon {
                    Image(uiImage: dynIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "house.and.flag.fill")
                        .font(.system(size: 25, weight: .regular))
                }
                Text(String(localized: "Home"))
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .foregroundStyle(
                AmisaSemanticColors.tabItemForeground(
                    isSelected: isSelected,
                    colorScheme: colorScheme
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Onglet générique

    private func tabItem(tab: MainTab, title: String, systemImage: String) -> some View {
        Button {
            router.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 25, weight: .regular))
                Text(title)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .foregroundStyle(
                AmisaSemanticColors.tabItemForeground(
                    isSelected: router.selectedTab == tab,
                    colorScheme: colorScheme
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(router.selectedTab == tab ? [.isSelected] : [])
    }
}

struct RightTabCapsule: View {
    @ObservedObject var router: Router
    @ObservedObject private var profileStore = ProfileStore.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            tabItem(tab: .favorites, title: String(localized: "Favoris"), systemImage: "heart.fill")
            profileTabItem
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background { LiquidGlassTabBarBackground() }
    }

    private var profileTabItem: some View {
        let isSelected = router.selectedTab == .profile
        let captionTint = AmisaSemanticColors.tabItemForeground(
            isSelected: isSelected,
            colorScheme: colorScheme
        )
        return Button {
            router.selectedTab = .profile
        } label: {
            VStack(spacing: 4) {
                Group {
                    ProfileTabAvatarView(
                        localUIImage: profileStore.avatarImage(),
                        remoteURLString: profileStore.avatarRemoteURLString,
                        isSelected: isSelected,
                        fallbackTint: captionTint
                    )
                }

                Text(String(localized: "Profil"))
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(captionTint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func tabItem(tab: MainTab, title: String, systemImage: String) -> some View {
        Button {
            router.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 25, weight: .regular))
                Text(title)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .foregroundStyle(
                AmisaSemanticColors.tabItemForeground(
                    isSelected: router.selectedTab == tab,
                    colorScheme: colorScheme
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(router.selectedTab == tab ? [.isSelected] : [])
    }
}

struct ScanFloatingButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 60, height: 60)
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Scanner ou photographier"))
    }
}
