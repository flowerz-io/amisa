//
//  AuthStartView.swift
//  Amisa
//
//  Écran 1 — Commencer : inscription e-mail/mot de passe + connexions sociales.
//

import SwiftUI

struct AuthStartView: View {
    let theme: AuthTheme
    let showsModalChrome: Bool
    let showsHandle: Bool
    let onContinueAsGuest: (@MainActor @Sendable () -> Void)?
    let onClose: @MainActor () -> Void
    let onEmailLogin: () -> Void

    @ObservedObject private var auth = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var localError: String?
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    private var isBusy: Bool {
        auth.isLoading || auth.isGoogleOAuthInProgress
    }

    var body: some View {
        AuthSheetFormScroll {
            startContent
        }
        .preferredColorScheme(theme.isPremium ? .dark : nil)
    }

    private var startContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsHandle {
                AuthModalHandle()
                    .frame(maxWidth: .infinity)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    AuthAmisaMark(theme: theme)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Commencer"))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(theme.primaryText)

                        Text(String(localized: "Crée ton compte pour retrouver tes analyses, favoris et recherches sur tous tes appareils."))
                            .font(.system(size: 14))
                            .foregroundStyle(theme.secondaryText)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if showsModalChrome {
                    AuthCloseButton(theme: theme, action: onClose)
                }
            }

            VStack(spacing: 12) {
                AuthIconEmailField(
                    theme: theme,
                    placeholder: String(localized: "Email"),
                    text: $email,
                    focused: $emailFocused,
                    onFocusChange: { isFocused in
                        if isFocused { AuthSheetLog.keyboard("email field focused (signup)") }
                    }
                )
                AuthIconPasswordField(
                    theme: theme,
                    placeholder: String(localized: "Password"),
                    text: $password,
                    contentType: .newPassword,
                    focused: $passwordFocused,
                    onFocusChange: { isFocused in
                        if isFocused { AuthSheetLog.keyboard("password field focused (signup)") }
                    }
                )
            }

            AuthPrimaryButton(
                title: String(localized: "Commencer"),
                isEnabled: canSubmitSignUp,
                isLoading: auth.isLoading && !auth.isGoogleOAuthInProgress
            ) {
                submitSignUp()
            }

            if let localError {
                AuthInlineErrorText(message: localError)
            } else if let err = auth.lastError, let msg = err.errorDescription {
                AuthInlineErrorText(message: msg)
            }

            Text(String(localized: "Ou se connecter avec"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)

            HStack(spacing: 12) {
                AuthSocialSquareButton(kind: .apple, isDisabled: isBusy) {
                    Task { await auth.signInWithApple() }
                }
                AuthSocialSquareButton(kind: .google, isDisabled: isBusy) {
                    Task {
                        do { try await auth.signInWithGoogle() }
                        catch { auth.lastError = .googleSignInFailed(error) }
                    }
                }
                AuthSocialSquareButton(kind: .email, isDisabled: isBusy) {
                    auth.lastError = nil
                    localError = nil
                    onEmailLogin()
                }
            }

            if auth.isGoogleOAuthInProgress {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(theme.accent)
                    Text(String(localized: "Ouverture de Google…"))
                        .font(.system(size: 13))
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }

            AuthLegalFooter(theme: theme)
                .frame(maxWidth: .infinity)

            if let onContinueAsGuest {
                AuthGuestContinueButton(theme: theme, action: onContinueAsGuest)
            }
        }
        .padding(.top, showsModalChrome ? (theme.isPremium ? 0 : 8) : 16)
        .padding(.horizontal, 24)
        .padding(.bottom, AuthSheetMetrics.bottomInset)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var canSubmitSignUp: Bool {
        AuthFormValidator.isValidEmail(email) && AuthFormValidator.isValidPassword(password)
    }

    private func submitSignUp() {
        localError = nil
        auth.lastError = nil

        guard AuthFormValidator.isValidEmail(email) else {
            localError = String(localized: "Adresse e-mail invalide.")
            return
        }
        guard AuthFormValidator.isValidPassword(password) else {
            localError = String(localized: "Le mot de passe doit contenir au moins 8 caractères.")
            return
        }

        Task {
            _ = await auth.signUpWithEmail(email: email, password: password)
        }
    }
}
