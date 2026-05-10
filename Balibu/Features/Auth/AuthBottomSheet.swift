//
//  AuthBottomSheet.swift
//  Balibu
//
//  Bottom sheet de connexion — Apple, Google, Email.
//  Présentée depuis OnboardingHeroView et ProfileView.
//
//  Usage :
//    .sheet(isPresented: $showAuth) {
//        AuthBottomSheet(onSignedIn: { ... }, onSkip: { ... })
//    }
//

import SwiftUI

// MARK: - AuthBottomSheet

struct AuthBottomSheet: View {

    /// Appelé dès que isAuthenticated passe à true.
    var onSignedIn: () -> Void
    /// Appelé si l'utilisateur tape "Continuer sans compte".
    var onSkip: (() -> Void)?

    @ObservedObject private var auth = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var screen: AuthScreen = .main

    private enum AuthScreen { case main, email, emailSent }

    var body: some View {
        ZStack {
            // Fond liquid glass géré par presentationBackground dans le parent
            Color.clear

            Group {
                switch screen {
                case .main:      mainView
                case .email:     EmailSignInView(onBack: { screen = .main },
                                                 onSent: { screen = .emailSent })
                case .emailSent: emailSentView
                }
            }
            .animation(.spring(response: 0.36, dampingFraction: 0.82), value: screen)
        }
        .onChange(of: auth.isAuthenticated) { _, authenticated in
            if authenticated {
                dismiss()
                onSignedIn()
            }
        }
    }

    // MARK: - Main screen

    private var mainView: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Drag handle centré
            handle
                .frame(maxWidth: .infinity, alignment: .center)

            // Header : icône + texte à gauche, croix à droite
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
                        Text("Commencer")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("Crée ton compte pour retrouver tes analyses, favoris et recherches sur tous tes appareils.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                closeButton
            }

            // Auth buttons
            VStack(spacing: 12) {
                authButton(label: "Continuer avec Apple",     sfSymbol: "apple.logo",    style: .filled)  { Task { await auth.signInWithApple()  } }
                authButton(label: "Continuer avec Google",    sfSymbol: "g.circle.fill", tint: .red, style: .filled) { Task { await auth.signInWithGoogle() } }
                authButton(label: "Continuer avec l'e-mail", sfSymbol: "envelope.fill",  style: .outlined) { screen = .email }
            }

            // Error
            if let err = auth.lastError, let msg = err.errorDescription {
                Text(msg)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignTokens.error)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }

            // Loading
            if auth.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }

            // Legal — compact
            legalText
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)

            // Skip option
            if let onSkip {
                Button {
                    dismiss()
                    onSkip()
                } label: {
                    Text("Continuer sans compte")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    // MARK: - Email sent confirmation

    private var emailSentView: some View {
        VStack(spacing: 0) {
            handle

            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor)
                }

                Text("Vérifie ta boîte mail")
                    .font(.system(size: 22, weight: .bold))

                Text("On t'a envoyé un lien sécurisé.\nTape dessus pour te connecter instantanément.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Fermer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .padding(.top, 6)
    }

    // MARK: - Reusable subviews

    private var handle: some View {
        Capsule()
            .fill(Color.primary.opacity(0.18))
            .frame(width: 36, height: 4)
            .padding(.bottom, 4)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }

    private enum AuthButtonStyle { case filled, outlined }

    private func authButton(
        label:    String,
        sfSymbol: String,
        tint:     Color = .primary,
        style:    AuthButtonStyle,
        action:   @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                // Texte centré sur toute la largeur
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(style == .filled ? Color.black : .primary)
                    .frame(maxWidth: .infinity)

                // Icône ancrée au bord leading
                HStack {
                    Image(systemName: sfSymbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(style == .filled ? Color.black : tint)
                        .frame(width: 24)
                    Spacer()
                }
                .padding(.horizontal, 22)
            }
            .frame(height: 64)
            // Filled = blanc opaque (lisible dark ET light mode)
            // Outlined = ultraThinMaterial avec bordure
            .background(
                style == .filled
                    ? AnyShapeStyle(Color.white)
                    : AnyShapeStyle(Material.ultraThin)
            )
            .clipShape(Capsule())
            .overlay(
                style == .outlined
                    ? AnyView(Capsule().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                    : AnyView(EmptyView())
            )
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(auth.isLoading)
    }

    private var legalText: some View {
        Group {
            Text("En continuant, tu acceptes les ")
                .foregroundStyle(.secondary)
            + Text("Conditions d'utilisation")
                .foregroundStyle(.secondary)
                .underline()
            + Text(" et la ")
                .foregroundStyle(.secondary)
            + Text("Politique de confidentialité")
                .foregroundStyle(.secondary)
                .underline()
            + Text(".")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .multilineTextAlignment(.center)
    }
}

// MARK: - EmailSignInView (intégré dans la bottom sheet)

private struct EmailSignInView: View {

    var onBack: () -> Void
    var onSent: () -> Void

    @ObservedObject private var auth = AuthManager.shared
    @State private var email = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Handle + back
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            // Content
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 8)

                    Text("Connexion par e-mail")
                        .font(.system(size: 22, weight: .bold))

                    Text("On t'envoie un lien sécurisé pour\nte connecter en un tap.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // Email field
                TextField("ton@email.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(Color.primary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(focused ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .focused($focused)
                    .padding(.horizontal, 20)
                    .onAppear { focused = true }

                // Send button
                Button {
                    Task {
                        let sent = await auth.signInWithEmail(email)
                        if sent { onSent() }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if auth.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Recevoir un lien de connexion")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(isValidEmail ? Color.accentColor : Color.accentColor.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(BouncyButtonStyle())
                .disabled(!isValidEmail || auth.isLoading)
                .padding(.horizontal, 20)

                if let err = auth.lastError, let msg = err.errorDescription {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }
            }

            Spacer(minLength: 24)
        }
    }

    private var isValidEmail: Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return e.contains("@") && e.contains(".")
    }
}

// MARK: - BouncyButtonStyle (redéclaration guard)
// Ce style est déjà défini dans OnboardingHeroView.swift — Swift le résout automatiquement
// dans le même module. Pas besoin de le redéfinir ici.
