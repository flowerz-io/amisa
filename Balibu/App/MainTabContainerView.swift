//
//  MainTabContainerView.swift
//  Balibu
//
//  Tab bar : Rechercher / Favoris / Réglages + bouton scan flottant (hors onglets).
//

import SwiftUI
import Combine
import UIKit

struct MainTabContainerView: View {
    @ObservedObject var router: Router
    let appDelegate: BalibuAppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCameraCapture = false
    @State private var bottomSafeInset: CGFloat = 34

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $router.selectedTab) {
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
                .tabItem {
                    Label(String(localized: "Rechercher"), systemImage: "magnifyingglass")
                }
                .tag(0)

                NavigationStack {
                    FavoritesView()
                        .environmentObject(router)
                }
                .tabItem {
                    Label(String(localized: "Favoris"), systemImage: "heart.fill")
                }
                .tag(1)

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label(String(localized: "Réglages"), systemImage: "gearshape.fill")
                }
                .tag(2)
            }
            .tint(.accentColor)

            floatingScanButton
        }
        .fullScreenCover(isPresented: $showCameraCapture) {
            CameraCaptureView { payload in
                showCameraCapture = false
                router.navigateToSharedImportReview(payload: payload)
            }
        }
        .onAppear {
            appDelegate.router = router
            refreshBottomSafeInset()
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

    private var floatingScanButton: some View {
        Button {
            showCameraCapture = true
        } label: {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 60, height: 60)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
                }
        }
        .buttonStyle(FloatingScanPressStyle())
        .accessibilityLabel(String(localized: "Scanner ou photographier"))
        .offset(x: 28)
        .padding(.bottom, bottomSafeInset + 49 + 10)
    }

    private func refreshBottomSafeInset() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }
        bottomSafeInset = window.safeAreaInsets.bottom
    }

    /// Ancien flux : fichier seul sans deep link id (clé legacy UserDefaults).
    private func checkPendingLegacySharedPayload() {
        let storage = ShareStorageService.shared
        guard let payload = storage.consumeLegacyFilenamePayload() else { return }
        router.navigateToSharedImportReview(payload: payload)
    }
}

// MARK: - Animation press (style proche des FAB système)

private struct FloatingScanPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.68), value: configuration.isPressed)
    }
}
