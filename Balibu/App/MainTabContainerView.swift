import SwiftUI
import Combine
import UIKit

struct MainTabContainerView: View {
    @ObservedObject var router: Router
    let appDelegate: BalibuAppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCameraCapture = false

    var body: some View {
        mainContent
            .overlay(alignment: .bottom) {
                bottomNavigationRow
            }
            .fullScreenCover(isPresented: $showCameraCapture) {
                CameraCaptureView { payload in
                    showCameraCapture = false
                    router.navigateToSharedImportReview(payload: payload)
                }
            }
            .onAppear {
                appDelegate.router = router
                Task { await NotificationManager.shared.refreshAuthorizationStatus() }
                router.processPendingShareImportIfNeeded()
                if router.path.isEmpty {
                    checkPendingLegacySharedPayload()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    router.processPendingShareImportIfNeeded()
                }
            }
    }

    private var mainContent: some View {
        ZStack {
            NavigationStack {
                DiscoveryHomeView()
                    .environmentObject(router)
            }
            .opacity(router.selectedTab == .home ? 1 : 0)
            .allowsHitTesting(router.selectedTab == .home)

            NavigationStack(path: $router.path) {
                SearchHomeView(searchHistoryService: .shared)
                    .environmentObject(router)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .home:
                            EmptyView()
                        case .sharedImportReview(let payload):
                            SharedImportReviewView(payload: payload)
                        case .shareImportProcessing(let payload):
                            ShareImportProcessingView(payload: payload)
                        case .results(let session):
                            ResultsView(session: session)
                        case .searchHistory:
                            SearchHistoryView()
                        }
                    }
            }
            .opacity(router.selectedTab == .search ? 1 : 0)
            .allowsHitTesting(router.selectedTab == .search)

            NavigationStack {
                ProfileView()
                    .environmentObject(router)
            }
            .opacity(router.selectedTab == .profile ? 1 : 0)
            .allowsHitTesting(router.selectedTab == .profile)
        }
        .tint(.accentColor)
    }

    private var bottomNavigationRow: some View {
        HStack(alignment: .center, spacing: 14) {
            tabBarCapsule
                .frame(maxWidth: .infinity)

            scanFloatingButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, bottomBarBottomPadding)
    }

    private var tabBarCapsule: some View {
        HStack(spacing: 0) {
            tabBarItem(tab: .home, title: String(localized: "Home"), systemImage: "house.fill")
            tabBarItem(tab: .search, title: String(localized: "Rechercher"), systemImage: "magnifyingglass")
            tabBarItem(tab: .profile, title: String(localized: "Profil"), systemImage: "face.dashed.fill")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
    }

    private func tabBarItem(tab: MainTab, title: String, systemImage: String) -> some View {
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
            .foregroundStyle(router.selectedTab == tab ? Color.accentColor : Color.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(router.selectedTab == tab ? [.isSelected] : [])
    }

    private var scanFloatingButton: some View {
        Button(action: openCamera) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 24, weight: .semibold))
            }
            .frame(width: 60, height: 60)
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Scanner ou photographier"))
    }

    private func openCamera() {
        showCameraCapture = true
    }

    private var bottomBarBottomPadding: CGFloat {
        let bottomInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom ?? 0

        return bottomInset > 0 ? 6 : 10
    }

    private func checkPendingLegacySharedPayload() {
        let storage = ShareStorageService.shared
        guard let payload = storage.consumeLegacyFilenamePayload() else { return }
        router.navigateToSharedImportReview(payload: payload)
    }
}
