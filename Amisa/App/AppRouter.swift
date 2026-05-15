//
//  AppRouter.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI
import Combine

enum AppRoute: Hashable {
    case home
    case sharedImportReview(payload: SharedImportPayload)
    case shareImportProcessing(payload: SharedImportPayload)
    case results(session: SearchSession)
    /// Recherche manuelle : animation puis résultats.
    case manualSearchLoading(query: String)
    case searchHistory
    /// Polling Railway jusqu’aux résultats (sessionId = pivot).
    case remoteSessionLoading(sessionId: String, continuitySeed: SearchSession?)
    case sharedSessionResumeFailed(message: String)
}

struct AppRouter: View {
    @ObservedObject var router: Router
    let appDelegate: AmisaAppDelegate

    @ObservedObject private var auth = AuthManager.shared
    @ObservedObject private var profileManager = ProfileManager.shared

    @AppStorage("amisa.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("amisa.colorScheme") private var colorSchemeRaw: Int = 0

    private var preferredScheme: ColorScheme? {
        switch colorSchemeRaw {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    /// Hydratation profil Supabase au retour de session (sans casser le mode invité).
    private var authenticatedUserId: String? {
        auth.isAuthenticated ? auth.currentUser?.id : nil
    }

    var body: some View {
        MainTabContainerView(router: router, appDelegate: appDelegate)
            .preferredColorScheme(preferredScheme)
            .task(id: authenticatedUserId) {
                if let id = authenticatedUserId {
                    await ProfileManager.shared.refreshProfileFromServer(userId: id)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { _ in }
            )) {
                OnboardingRootView {
                    hasCompletedOnboarding = true
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: {
                    hasCompletedOnboarding
                        && auth.isAuthenticated
                        && profileManager.needsMandatoryProfileCompletion
                },
                set: { _ in }
            )) {
                CompleteProfileView()
                    .interactiveDismissDisabled()
            }
    }
}
