import SwiftUI
import Combine
import UIKit

struct MainTabContainerView: View {
    @ObservedObject var router: Router
    let appDelegate: BalibuAppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCameraCapture = false

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent
                .padding(.bottom, Self.scrollContentBottomInset)

            BottomNavigationRow(router: router, onScan: { showCameraCapture = true })
                .padding(.horizontal, 20)
                .padding(.bottom, Self.bottomBarAnchorPadding)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .ignoresSafeArea(.container, edges: .bottom)
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

    /// Réserve de l’espace pour le scroll afin que le dernier contenu ne passe pas sous la barre flottante (indépendant du positionnement visuel de la barre).
    private static let scrollContentBottomInset: CGFloat = 98
    /// Marge entre le bord bas de l’écran (hors safe area) et la barre — ne doit pas servir à inset le contenu scrollable.
    private static let bottomBarAnchorPadding: CGFloat = 16

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
                FavoritesView()
                    .environmentObject(router)
            }
            .opacity(router.selectedTab == .favorites ? 1 : 0)
            .allowsHitTesting(router.selectedTab == .favorites)

            NavigationStack {
                ProfileView()
                    .environmentObject(router)
            }
            .opacity(router.selectedTab == .profile ? 1 : 0)
            .allowsHitTesting(router.selectedTab == .profile)
        }
        .tint(.accentColor)
    }

    private func checkPendingLegacySharedPayload() {
        let storage = ShareStorageService.shared
        guard let payload = storage.consumeLegacyFilenamePayload() else { return }
        router.navigateToSharedImportReview(payload: payload)
    }
}
