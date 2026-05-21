//
//  AuthBottomSheet.swift
//  Balibu
//
//  Connexion — Apple, Google, Email — partagée entre sheet modale et étape onboarding.
//

import SwiftUI

// MARK: - Sheet modale

struct AuthBottomSheet: View {
    var onSignedIn: () -> Void
    var onSkip: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AuthCoordinatorCore(
            embed: .modalSheet(close: { dismiss() }),
            skipTrailing: onSkip.map { callback in {
                dismiss()
                Task { @MainActor in callback() }
            }},
            onAuthenticated: onSignedIn
        )
    }
}

// MARK: - Cœur du flux auth

/// `embed` distingue la sheet (fermeture complète du conteneur) et l’onboarding inline.
struct AuthCoordinatorCore: View {

    enum EmbedKind {
        case modalSheet(close: () -> Void)
        case onboardingInline
    }

    let embed: EmbedKind
    /// Bouton « Continuer sans compte » ; pour la modal, inclut la fermeture du parent avant le callback utilisateur.
    var skipTrailing: (() -> Void)? = nil

    /// Succès OAuth / session ; appeler côté app sur MainActor après fermeture modale si besoin.
    let onAuthenticated: @MainActor () -> Void

    @ObservedObject private var auth = AuthManager.shared
    @State private var screen: AuthScreen = .main

    private enum AuthScreen {
        case main, email, emailSent
    }

    private func closeModalOnly() {
        if case .modalSheet(let close) = embed {
            close()
        }
    }

    private func emailSentDismiss() {
        switch embed {
        case .modalSheet(let close): close()
        case .onboardingInline: screen = .main
        }
    }

    var body: some View {
        Group {
            switch screen {
            case .main:
                mainScreen
            case .email:
                AuthEmailMagicLinkView(
                    onBack: { screen = .main },
                    onSent: { screen = .emailSent }
                )
            case .emailSent:
                emailSentConfirmation
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: screen)
        .onChange(of: auth.isAuthenticated) { _, ok in
            guard ok else { return }
            print("[Onboarding] auth success")
            Task { await MainActor.run {
                closeModalOnly()
                onAuthenticated()
            }}
        }
    }

    // MARK: - Main

    private var mainScreen: some View {
        let isSheet: Bool = {
            if case .modalSheet = embed { return true }
            return false
        }()

        return VStack(alignment: .leading, spacing: 18) {
            if isSheet {
                authHandle
                    .frame(maxWidth: .infinity)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Commencer"))
                            .font(.system(size: 26, weight: .bold))

                        Text("Crée ton compte pour retrouver tes analyses, favoris et recherches sur tous tes appareils.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if isSheet {
                    Button {
                        closeModalOnly()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }
            }

            authButtonsGrid

            if let err = auth.lastError, let msg = err.errorDescription {
                Text(msg)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignTokens.error)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            if auth.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            }

            if auth.isGoogleOAuthInProgress {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(String(localized: "Ouverture de Google…"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            legalBloc
                .frame(maxWidth: .infinity)

            if let skipTrailing {
                Button {
                    Task { @MainActor in skipTrailing() }
                } label: {
                    Text(String(localized: "Continuer sans compte"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, isSheet ? 12 : 22)
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private var authButtonsGrid: some View {
        VStack(spacing: 12) {
            authStyledButton(title: String(localized: "Continuer avec Apple"), sf: "apple.logo", filled: true) {
                Task { await auth.signInWithApple() }
            }
            googleButton
            authStyledButton(title: String(localized: "Continuer avec l'e-mail"), sf: "envelope.fill", filled: false) {
                screen = .email
            }
        }
    }

    private var googleButton: some View {
        Button {
            Task {
                do { try await auth.signInWithGoogle() }
                catch { auth.lastError = .googleSignInFailed(error) }
            }
        } label: {
            ZStack {
                Text(String(localized: "Continuer avec Google"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                HStack {
                    Image(systemName: "g.circle.fill").foregroundStyle(Color.red).frame(width: 24)
                    Spacer()
                }
                .padding(.horizontal, 22)
            }
            .frame(height: 64)
            .background(Color.white).clipShape(Capsule())
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(auth.isLoading || auth.isGoogleOAuthInProgress)
    }

    private func authStyledButton(title: String, sf: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(filled ? Color.black : .primary)
                    .frame(maxWidth: .infinity)
                HStack {
                    Image(systemName: sf)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(filled ? Color.black : Color.primary)
                        .frame(width: 24)
                    Spacer()
                }
                .padding(.horizontal, 22)
            }
            .frame(height: 64)
            .background(filled ? AnyShapeStyle(Color.white) : AnyShapeStyle(Material.ultraThin))
            .clipShape(Capsule())
            .overlay(
                Group {
                    if !filled {
                        Capsule().stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(auth.isLoading || auth.isGoogleOAuthInProgress)
    }

    private var legalBloc: some View {
        Group {
            Text("En continuant, tu acceptes les ").foregroundStyle(.secondary)
                + Text("Conditions d'utilisation").foregroundStyle(.secondary).underline()
                + Text(" et la ").foregroundStyle(.secondary)
                + Text("Politique de confidentialité").foregroundStyle(.secondary).underline()
                + Text(".").foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .multilineTextAlignment(.center)
        .padding(.top, 4)
    }

    private var authHandle: some View {
        Capsule()
            .fill(Color.primary.opacity(0.18))
            .frame(width: 36, height: 4)
            .padding(.bottom, 4)
    }

    // MARK: - Email envoyé

    private var emailSentConfirmation: some View {
        VStack(spacing: 0) {
            if case .modalSheet = embed { authHandle }
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 80, height: 80)
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor)
                }
                Text("Vérifie ta boîte mail").font(.system(size: 22, weight: .bold))
                Text("On t'a envoyé un lien sécurisé.\nTape dessus pour te connecter instantanément.")
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
            }
            Spacer()
            Button {
                Task { await MainActor.run { emailSentDismiss() }}
            } label: {
                Text(String(localized: "Fermer"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .padding(.top, 6)
    }
}

// MARK: - Email champ

struct AuthEmailMagicLinkView: View {

    var onBack: () -> Void
    var onSent: () -> Void

    @ObservedObject private var auth = AuthManager.shared
    @State private var email = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .padding(10)
                        .background(Color.primary.opacity(0.06)).clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 14)

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 28)).foregroundStyle(Color.accentColor).padding(.top, 8)
                    Text("Connexion par e-mail").font(.system(size: 22, weight: .bold))
                    Text("On t'envoie un lien sécurisé pour\nte connecter en un tap.")
                        .font(.system(size: 14)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }.padding(.top, 8)

                TextField("ton@email.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 16).padding(.vertical, 15)
                    .background(Color.primary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(focused ? Color.accentColor : Color.primary.opacity(0.12)))
                    .focused($focused).padding(.horizontal, 20)
                    .onAppear { focused = true }

                Button {
                    Task {
                        if await auth.signInWithEmail(email) { onSent() }
                    }
                } label: {
                    Group {
                        if auth.isLoading { ProgressView().tint(.white) }
                        else {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .semibold))
                                Text("Recevoir un lien de connexion").font(.system(size: 16, weight: .semibold))
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(isOk ? Color.accentColor : Color.accentColor.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(BouncyButtonStyle())
                .disabled(!isOk || auth.isLoading || auth.isGoogleOAuthInProgress)
                .padding(.horizontal, 20)

                if let err = auth.lastError, let msg = err.errorDescription {
                    Text(msg).foregroundStyle(DesignTokens.error).font(.system(size: 13)).padding(.horizontal)
                }
            }

            Spacer(minLength: 24)
        }
    }

    private var isOk: Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return e.contains("@") && e.contains(".")
    }
}
