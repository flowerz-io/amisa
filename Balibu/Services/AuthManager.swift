//
//  AuthManager.swift
//  Balibu
//
//  Singleton d'authentification — Apple, Google, Email (magic link).
//  Source de vérité pour l'état connecté dans toute l'app.
//

import AuthenticationServices
import Combine
import Foundation
import UIKit

// MARK: - AuthError

enum AuthError: LocalizedError {
    case appleSignInCancelled
    case appleSignInFailed(Error)
    case googleSignInFailed(Error)
    case emailSignInFailed(Error)
    case signOutFailed(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .appleSignInCancelled:      return nil
        case .appleSignInFailed:         return "La connexion Apple a échoué."
        case .googleSignInFailed:        return "La connexion Google a échoué."
        case .emailSignInFailed:         return "L'envoi du lien a échoué."
        case .signOutFailed:             return "La déconnexion a échoué."
        case .unknown:                   return "Une erreur est survenue."
        }
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
    @Published var lastError: AuthError?

    // MARK: - Private

    private var appleSignInContinuation: CheckedContinuation<AppUser, Error>?

    private override init() {
        super.init()
        // TODO: Une fois Supabase configuré, observer l'état auth au lancement :
        // Task { await observeSupabaseAuthState() }
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

    // MARK: - Google Sign In

    func signInWithGoogle() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        // TODO: Installer le SDK Google Sign In :
        //   https://github.com/google/GoogleSignIn-iOS
        //   Puis ajouter dans Info.plist le CFBundleURLTypes avec REVERSED_CLIENT_ID.
        //
        // Exemple d'implémentation réelle :
        //
        // guard let windowScene = UIApplication.shared.connectedScenes
        //     .compactMap({ $0 as? UIWindowScene })
        //     .first(where: { $0.activationState == .foregroundActive }),
        //       let rootVC = windowScene.windows.first?.rootViewController else { return }
        //
        // do {
        //     let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        //     guard let idToken = result.user.idToken?.tokenString else { return }
        //     let accessToken = result.user.accessToken.tokenString
        //     let user = try await SupabaseManager.shared.signInWithGoogle(
        //         idToken: idToken, accessToken: accessToken
        //     )
        //     await finalize(user)
        // } catch {
        //     self.lastError = .googleSignInFailed(error)
        // }

        // Simulation temporaire (à remplacer par le vrai SDK)
        let mock = AppUser(
            id: UUID().uuidString,
            email: "demo@gmail.com",
            fullName: "Demo User",
            avatarURL: nil
        )
        await finalize(mock)
    }

    // MARK: - Email magic link

    /// Retourne `true` si le lien a bien été envoyé.
    func signInWithEmail(_ email: String) async -> Bool {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            try await SupabaseManager.shared.sendMagicLink(email: email)
            return true
        } catch {
            lastError = .emailSignInFailed(error)
            return false
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
            ProfileStore.shared.save(firstName: "", lastName: "", avatarFileName: nil)
        } catch {
            lastError = .signOutFailed(error)
        }
    }

    // MARK: - Internal

    private func finalize(_ user: AppUser) async {
        currentUser = user
        isAuthenticated = true
        await ProfileManager.shared.syncAfterSignIn(user: user)
    }

    // MARK: - Supabase auth state (à décommenter une fois le SDK installé)
    //
    // private func observeSupabaseAuthState() async {
    //     for await (event, session) in await supabaseClient.auth.authStateChanges {
    //         switch event {
    //         case .signedIn:
    //             if let s = session {
    //                 let user = AppUser(
    //                     id: s.user.id.uuidString,
    //                     email: s.user.email,
    //                     fullName: s.user.userMetadata["full_name"] as? String,
    //                     avatarURL: (s.user.userMetadata["avatar_url"] as? String).flatMap(URL.init)
    //                 )
    //                 await finalize(user)
    //             }
    //         case .signedOut:
    //             currentUser = nil
    //             isAuthenticated = false
    //         default:
    //             break
    //         }
    //     }
    // }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthManager: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in
                appleSignInContinuation?.resume(throwing: AuthError.unknown)
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
