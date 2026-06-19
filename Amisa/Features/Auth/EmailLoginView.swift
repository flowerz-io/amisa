//
//  EmailLoginView.swift
//  Amisa
//
//  Écran 2 — Connexion par e-mail et mot de passe.
//

import SwiftUI

struct EmailLoginView: View {
    let theme: AuthTheme
    let onBack: () -> Void

    @ObservedObject private var auth = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var localError: String?
    @State private var resetSuccessMessage: String?
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    var body: some View {
        AuthSheetFormScroll {
            loginContent
        }
        .onAppear {
            AuthSheetLog.emailLogin("view appeared")
        }
        .preferredColorScheme(theme.isPremium ? .dark : nil)
    }

    private var loginContent: some View {
        VStack(spacing: 0) {
            HStack {
                AuthRedBackButton(action: onBack)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(BrandColors.primaryRed)
                        .padding(.top, 4)

                    Text(String(localized: "Connexion par e-mail"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                        .multilineTextAlignment(.center)

                    Text(String(localized: "Connecte-toi à l’aide de tes identifiants"))
                        .font(.system(size: 14))
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    AuthIconEmailField(
                        theme: theme,
                        placeholder: String(localized: "Email"),
                        text: $email,
                        focused: $emailFocused,
                        onFocusChange: { isFocused in
                            if isFocused { AuthSheetLog.keyboard("email field focused (login)") }
                        }
                    )
                    AuthIconPasswordField(
                        theme: theme,
                        placeholder: String(localized: "Password"),
                        text: $password,
                        contentType: .password,
                        focused: $passwordFocused,
                        onFocusChange: { isFocused in
                            if isFocused { AuthSheetLog.keyboard("password field focused (login)") }
                        }
                    )
                }
                .padding(.horizontal, 20)

                Button(action: resetPasswordTapped) {
                    Text(String(localized: "Mot de passe oublié"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.primaryText)
                        .underline()
                }
                .buttonStyle(.plain)

                AuthPrimaryButton(
                    title: String(localized: "Se connecter"),
                    isEnabled: canSubmit,
                    isLoading: auth.isLoading
                ) {
                    submitLogin()
                }
                .padding(.horizontal, 20)

                if let resetSuccessMessage {
                    AuthSuccessText(message: resetSuccessMessage, theme: theme)
                        .padding(.horizontal, 20)
                }

                if let localError {
                    AuthInlineErrorText(message: localError)
                        .padding(.horizontal, 20)
                } else if let err = auth.lastError, let msg = err.errorDescription {
                    AuthInlineErrorText(message: msg)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, AuthSheetMetrics.bottomInset)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var canSubmit: Bool {
        AuthFormValidator.isValidEmail(email) && !password.isEmpty
    }

    private func submitLogin() {
        AuthSheetLog.emailLogin("submit tapped")
        resetSuccessMessage = nil
        localError = nil
        auth.lastError = nil

        guard AuthFormValidator.isValidEmail(email) else {
            localError = String(localized: "Adresse e-mail invalide.")
            return
        }
        guard !password.isEmpty else {
            localError = String(localized: "Saisis ton mot de passe.")
            return
        }

        Task {
            _ = await auth.signInWithEmailPassword(email: email, password: password)
        }
    }

    private func resetPasswordTapped() {
        AuthSheetLog.emailLogin("forgot password tapped")
        resetSuccessMessage = nil
        localError = nil
        auth.lastError = nil

        guard AuthFormValidator.isValidEmail(email) else {
            localError = String(localized: "Saisis ton e-mail pour réinitialiser ton mot de passe.")
            return
        }

        Task {
            if await auth.resetPassword(email: email) {
                resetSuccessMessage = String(localized: "Un e-mail de réinitialisation a été envoyé.")
            }
        }
    }
}
