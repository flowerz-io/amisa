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
    }
}

struct LeftTabCapsule: View {
    @ObservedObject var router: Router
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            tabItem(tab: .home, title: String(localized: "Home"), systemImage: "house.and.flag.fill")
            tabItem(tab: .search, title: String(localized: "Recherche"), systemImage: "magnifyingglass")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
    }

    private func tabItem(tab: MainTab, title: String, systemImage: String) -> some View {
        Button {
            router.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .regular))
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .foregroundStyle(
                BalibuSemanticColors.tabItemForeground(
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            tabItem(tab: .favorites, title: String(localized: "Favoris"), systemImage: "heart.fill")
            tabItem(tab: .profile, title: String(localized: "Profil"), systemImage: "face.dashed.fill")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
    }

    private func tabItem(tab: MainTab, title: String, systemImage: String) -> some View {
        Button {
            router.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .regular))
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .foregroundStyle(
                BalibuSemanticColors.tabItemForeground(
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
