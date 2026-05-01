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
    case searchHistory
    /// Polling Railway jusqu’aux résultats (sessionId = pivot).
    case remoteSessionLoading(sessionId: String)
    case sharedSessionResumeFailed(message: String)
}

struct AppRouter: View {
    @ObservedObject var router: Router
    let appDelegate: BalibuAppDelegate

    @AppStorage("balibu.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        MainTabContainerView(router: router, appDelegate: appDelegate)
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { _ in }
            )) {
                OnboardingRootView {
                    hasCompletedOnboarding = true
                }
            }
    }
}
