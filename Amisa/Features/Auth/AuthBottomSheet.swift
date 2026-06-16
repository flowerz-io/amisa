//
//  AuthBottomSheet.swift
//  Balibu
//
//  Connexion — inscription, e-mail + mot de passe, Apple / Google.
//

import SwiftUI

// MARK: - Sheet modale

struct AuthBottomSheet: View {
    var onSignedIn: @MainActor @Sendable () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sheetHeight: CGFloat = AuthSheetMetrics.fallbackHeight

    var body: some View {
        AuthCoordinatorCore(
            embed: .modalSheet(close: { dismiss() }),
            onContinueAsGuest: nil,
            onAuthenticated: { @MainActor in onSignedIn() }
        )
        .reportAuthSheetHeight()
        .onPreferenceChange(AuthSheetHeightKey.self) { measured in
            guard measured > 0 else { return }
            let capped = min(
                measured,
                AuthSheetMetrics.maxSheetHeight(for: UIScreen.main.bounds.height)
            )
            withAnimation(.easeOut(duration: 0.2)) {
                sheetHeight = capped
            }
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(.ultraThinMaterial)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Cœur du flux auth

struct AuthCoordinatorCore: View {

    enum EmbedKind {
        case modalSheet(close: () -> Void)
        case onboardingInline
        case onboardingPremium(close: () -> Void)
    }

    let embed: EmbedKind
    var onContinueAsGuest: (@MainActor @Sendable () -> Void)? = nil
    let onAuthenticated: @MainActor @Sendable () -> Void

    @ObservedObject private var auth = AuthManager.shared
    @State private var screen: AuthScreen = .start

    private enum AuthScreen {
        case start
        case emailLogin
    }

    private var theme: AuthTheme {
        AuthTheme(isPremium: isOnboardingPremium)
    }

    private var isOnboardingPremium: Bool {
        if case .onboardingPremium = embed { return true }
        return false
    }

    private var showsModalChrome: Bool {
        switch embed {
        case .modalSheet, .onboardingPremium: return true
        case .onboardingInline: return false
        }
    }

    private var showsHandle: Bool {
        if case .modalSheet = embed { return true }
        return false
    }

    private func closeModalOnly() {
        switch embed {
        case .modalSheet(let close), .onboardingPremium(let close):
            close()
        case .onboardingInline:
            break
        }
    }

    var body: some View {
        Group {
            switch screen {
            case .start:
                AuthStartView(
                    theme: theme,
                    showsModalChrome: showsModalChrome,
                    showsHandle: showsHandle,
                    onContinueAsGuest: onContinueAsGuest.map { handler in
                        { @MainActor @Sendable in handler() }
                    },
                    onClose: { @MainActor in closeModalOnly() },
                    onEmailLogin: { screen = .emailLogin }
                )
            case .emailLogin:
                EmailLoginView(
                    theme: theme,
                    onBack: { screen = .start }
                )
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: screen)
        .onChange(of: auth.isAuthenticated) { _, ok in
            guard ok else { return }
            Task { await MainActor.run {
                closeModalOnly()
                onAuthenticated()
            }}
        }
    }
}
