//
//  AuthManager.swift
//  Balibu
//
//  Singleton d'authentification — Apple, Google, e-mail + mot de passe.
//  Source de vérité pour l'état connecté dans toute l'app.
//

import AuthenticationServices
import Combine
import Foundation
import Supabase
import UIKit

// MARK: - AppAuthError

enum AppAuthError: LocalizedError {
    case appleSignInCancelled
    case appleSignInFailed(Error)
    case googleSignInFailed(Error)
    case emailAlreadyInUse
    case invalidCredentials
    case userNotFound
    case emailAuthFailed(Error)
    case networkError
    /// Retour `amisa://auth-callback` (OAuth Google ou réinitialisation mot de passe).
    case authRedirectFailed(Error)
    case signOutFailed(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .appleSignInCancelled:
            return nil
        case .appleSignInFailed:
            return "La connexion Apple a échoué."
        case .googleSignInFailed(let error):
            return Self.describeUnderlyingSupabaseError(error)
        case .emailAlreadyInUse:
            return "Cette adresse e-mail est déjà utilisée."
        case .invalidCredentials:
            return "Mot de passe incorrect."
        case .userNotFound:
            return "Aucun compte trouvé avec cette adresse e-mail."
        case .emailAuthFailed(let error):
            return Self.describeUnderlyingSupabaseError(error)
        case .networkError:
            return "Problème de connexion. Vérifie ton réseau et réessaie."
        case .authRedirectFailed(let error):
            return Self.describeUnderlyingSupabaseError(error)
        case .signOutFailed(let error):
            return Self.describeUnderlyingSupabaseError(error)
        case .unknown:
            return "Une erreur est survenue."
        }
    }

    /// Texte affiché tel quel dans l’UI (erreurs réseau / GoTrue).
    private static func describeUnderlyingSupabaseError(_ error: Error) -> String {
        if let mapped = mapKnownAuthAPIError(error) {
            return mapped.errorDescription ?? "Une erreur est survenue."
        }
        if let le = error as? LocalizedError {
            if let d = le.errorDescription, !d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return d
            }
            if let r = le.failureReason, !r.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return r
            }
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return AppAuthError.networkError.errorDescription!
        }
        if !ns.localizedDescription.isEmpty, ns.localizedDescription != "(null)" {
            return ns.localizedDescription
        }
        let s = String(describing: error)
        return s.isEmpty ? "Une erreur est survenue." : s
    }

    static func mapKnownAuthAPIError(_ error: Error) -> AppAuthError? {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return .networkError
        }

        let message = ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            .lowercased()

        if message.contains("already registered")
            || message.contains("already been registered")
            || message.contains("user already registered") {
            return .emailAlreadyInUse
        }
        if message.contains("invalid login credentials")
            || message.contains("invalid credentials")
            || message.contains("wrong password") {
            return .invalidCredentials
        }
        if message.contains("user not found")
            || message.contains("no user found") {
            return .userNotFound
        }
        if message.contains("network")
            || message.contains("internet")
            || message.contains("timed out")
            || message.contains("could not connect") {
            return .networkError
        }
        return nil
    }
}

// MARK: - AuthManager

@MainActor
final class AuthManager: NSObject, ObservableObject {

    static let shared = AuthManager()

    // MARK: - Published state

    @Published private(set) var currentUser: AppUser?
    @Published private(set) var isAuthenticated = false
    @Published var isLoading = false
    /// Pendant l’ouverture du navigateur OAuth Google (distinct de `isLoading` Apple / email).
    @Published private(set) var isGoogleOAuthInProgress = false
    @Published var lastError: AppAuthError?

    // MARK: - Private

    private var appleSignInContinuation: CheckedContinuation<AppUser, Error>?

    private override init() {
        super.init()
        Task { await observeSupabaseAuthState() }
    }

    // MARK: - Apple Sign In

    func signInWithApple() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let user = try await performAppleSignIn()
            await finalize(user)
        } catch let err as ASAuthorizationError where err.code == .canceled {
            // Annulation silencieuse — pas d'erreur affichée
        } catch {
            lastError = .appleSignInFailed(error)
        }
    }

    private func performAppleSignIn() async throws -> AppUser {
        return try await withCheckedThrowingContinuation { continuation in
            self.appleSignInContinuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Google OAuth (Supabase)

    func signInWithGoogle() async throws {
        guard SupabaseManager.shared.isConfigured else {
            throw NSError(
                domain: "Auth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Supabase n’est pas configuré."]
            )
        }

        isGoogleOAuthInProgress = true
        lastError = nil
        defer { isGoogleOAuthInProgress = false }

        let session = try await SupabaseManager.shared.signInWithGoogleOAuth()
        await finalize(SupabaseManager.shared.appUser(from: session.user))
    }

    // MARK: - Email + mot de passe

    /// Crée un compte. Retourne `true` si la session est établie.
    func signUpWithEmail(email: String, password: String) async -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AuthFormValidator.isValidEmail(trimmedEmail),
              AuthFormValidator.isValidPassword(password) else { return false }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let user = try await SupabaseManager.shared.signUpWithEmailPassword(
                email: trimmedEmail,
                password: password
            )
            await finalize(user)
            return true
        } catch {
            lastError = Self.mapEmailAuthError(error)
            return false
        }
    }

    /// Connexion e-mail + mot de passe. Retourne `true` si la session est établie.
    func signInWithEmailPassword(email: String, password: String) async -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AuthFormValidator.isValidEmail(trimmedEmail), !password.isEmpty else { return false }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let user = try await SupabaseManager.shared.signInWithEmailPassword(
                email: trimmedEmail,
                password: password
            )
            await finalize(user)
            return true
        } catch {
            lastError = Self.mapEmailAuthError(error)
            return false
        }
    }

    /// Envoie un e-mail de réinitialisation du mot de passe.
    func resetPassword(email: String) async -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AuthFormValidator.isValidEmail(trimmedEmail) else { return false }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            try await SupabaseManager.shared.resetPasswordForEmail(trimmedEmail)
            return true
        } catch {
            lastError = Self.mapEmailAuthError(error)
            return false
        }
    }

    private static func mapEmailAuthError(_ error: Error) -> AppAuthError {
        if let known = AppAuthError.mapKnownAuthAPIError(error) {
            return known
        }
        return .emailAuthFailed(error)
    }

    /// OAuth Google ou réinitialisation mot de passe : `amisa://auth-callback`.
    func handleAuthRedirect(url: URL) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            _ = try await SupabaseManager.shared.finishAuthRedirect(from: url)
            let user = try await SupabaseManager.shared.fetchCurrentSessionUser()
            await finalize(user)
        } catch {
            lastError = .authRedirectFailed(error)
            print("[GOOGLE_AUTH] auth redirect failed:", error.localizedDescription)
        }
    }

    private func observeSupabaseAuthState() async {
        guard let stream = SupabaseManager.shared.authStateChangesStream() else { return }
        for await change in stream {
            await applySupabaseAuthChange(event: change.event, session: change.session)
        }
    }

    private func applySupabaseAuthChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession, .signedIn:
            guard let session else { return }
            await finalize(SupabaseManager.shared.appUser(from: session.user))
        case .userUpdated:
            if let session {
                await finalize(SupabaseManager.shared.appUser(from: session.user))
            }
        case .signedOut:
            currentUser = nil
            isAuthenticated = false
            await ProfileManager.shared.clear()
            ProfileStore.shared.clearSupabaseRemoteOverlay()
        default:
            break
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await SupabaseManager.shared.signOut()
            currentUser = nil
            isAuthenticated = false
            await ProfileManager.shared.clear()
            ProfileStore.shared.clearSupabaseRemoteOverlay()
        } catch {
            lastError = .signOutFailed(error)
        }
    }

    /// Après suppression de compte côté serveur — réinitialise l’état local sans nouvel appel signOut.
    func resetAfterAccountDeletion() {
        currentUser = nil
        isAuthenticated = false
        lastError = nil
        isLoading = false
        isGoogleOAuthInProgress = false
    }

    // MARK: - Internal

    private func finalize(_ user: AppUser) async {
        GuestSessionStore.shared.exitGuestMode()
        currentUser = user
        isAuthenticated = true
        await ProfileManager.shared.syncAfterSignIn(user: user)
    }

}

// MARK: - ASAuthorizationControllerDelegate

extension AuthManager: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in
                appleSignInContinuation?.resume(throwing: AppAuthError.unknown)
                appleSignInContinuation = nil
            }
            return
        }

        Task {
            do {
                let user: AppUser
                if let tokenData = credential.identityToken,
                   let token = String(data: tokenData, encoding: .utf8) {
                    user = try await SupabaseManager.shared.signInWithApple(identityToken: token)
                } else {
                    let givenName  = credential.fullName?.givenName  ?? ""
                    let familyName = credential.fullName?.familyName ?? ""
                    let full = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
                    user = AppUser(
                        id: credential.user,
                        email: credential.email,
                        fullName: full.isEmpty ? nil : full,
                        avatarURL: nil
                    )
                }
                await MainActor.run {
                    self.appleSignInContinuation?.resume(returning: user)
                    self.appleSignInContinuation = nil
                }
            } catch {
                await MainActor.run {
                    self.appleSignInContinuation?.resume(throwing: error)
                    self.appleSignInContinuation = nil
                }
            }
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            appleSignInContinuation?.resume(throwing: error)
            appleSignInContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        DispatchQueue.main.sync {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            let activeScene = scenes.first { $0.activationState == .foregroundActive }
            let window = activeScene?.windows.first { $0.isKeyWindow }
                ?? scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
                ?? scenes.flatMap { $0.windows }.first
            return window ?? ASPresentationAnchor()
        }
    }
}
