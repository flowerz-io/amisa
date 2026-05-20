//
//  SupabaseManager.swift
//  Balibu
//
//  Couche d'accès Supabase (Auth réel via SDK).
//

import Foundation
import Supabase

enum SupabaseManagerError: LocalizedError {
    case notConfigured(reason: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let reason):
            return reason
        }
    }
}

// MARK: - SupabaseManager

final class SupabaseManager {
    static let shared = SupabaseManager()

    private let client: SupabaseClient?
    /// Raison si le client n’a pas pu être créé (pour `requireClient()` et les logs).
    private let configurationFailureReason: String

    private init() {
        let rawURLFromPlist = Bundle.main.object(forInfoDictionaryKey: SupabaseConfig.plistURLKey) as? String
        let rawKeyFromPlist = Bundle.main.object(forInfoDictionaryKey: SupabaseConfig.plistAnonKeyKey) as? String

        let urlCandidate = SupabaseConfig.normalizeCredential(rawURLFromPlist)
        let anonCandidate = SupabaseConfig.normalizeCredential(rawKeyFromPlist)

        #if DEBUG
        print("[Supabase][Config] plist brut SUPABASE_URL : \(rawURLFromPlist ?? "nil")")
        print("[Supabase][Config] plist brut SUPABASE_ANON_KEY : \(rawKeyFromPlist.map { _ in "(présent, masqué)" } ?? "nil")")
        print("[Supabase][Config] SUPABASE_URL après trim/normalisation : \(urlCandidate)")
        #endif

        if urlCandidate.isEmpty {
            configurationFailureReason =
                "SUPABASE_URL est vide ou absent : vérifie \(SupabaseConfig.plistURLKey) dans Info.plist de l’application."
            client = nil
            #if DEBUG
            print("[Supabase][Config] création client annulée : URL vide")
            #endif
            return
        }

        if urlCandidate.localizedCaseInsensitiveContains(SupabaseConfig.legacyWrongSupabaseURLMarker) {
            configurationFailureReason = "Ancienne URL Supabase détectée."
            client = nil
            #if DEBUG
            print("[Supabase][Config] création client annulée : ancienne URL (marqueur \(SupabaseConfig.legacyWrongSupabaseURLMarker))")
            #endif
            return
        }

        guard urlCandidate.hasPrefix("https://") else {
            configurationFailureReason =
                "SUPABASE_URL doit commencer par https:// (valeur normalisée invalide)."
            client = nil
            #if DEBUG
            print("[Supabase][Config] création client annulée : schème invalide")
            #endif
            return
        }

        guard let supabaseURL = URL(string: urlCandidate), supabaseURL.host?.isEmpty == false else {
            configurationFailureReason =
                "SUPABASE_URL n’est pas une URL valide après normalisation (host introuvable)."
            client = nil
            #if DEBUG
            print("[Supabase][Config] création client annulée : URL(string:) ou host invalide")
            #endif
            return
        }

        guard !anonCandidate.isEmpty else {
            configurationFailureReason =
                "SUPABASE_ANON_KEY est vide ou absent : vérifie \(SupabaseConfig.plistAnonKeyKey) dans Info.plist de l’application."
            client = nil
            #if DEBUG
            print("[Supabase][Config] création client annulée : clé anon vide")
            #endif
            return
        }

        guard !anonCandidate.localizedCaseInsensitiveContains("YOUR_SUPABASE_ANON_KEY") else {
            configurationFailureReason =
                "SUPABASE_ANON_KEY est encore le placeholder : remplace-le par la clé anon du dashboard Supabase."
            client = nil
            #if DEBUG
            print("[Supabase][Config] création client annulée : placeholder anon key")
            #endif
            return
        }

        let supabaseAnonKey = anonCandidate

        print("[SupabaseConfig] URL utilisée =", supabaseURL.absoluteString)

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        configurationFailureReason = ""
    }

    /// `true` si URL et clé anon sont renseignées (pas les placeholders).
    var isConfigured: Bool { client != nil }

    /// Accès au client pour diagnostics ; préférer les méthodes typées (`signInWithGoogleOAuth`, etc.).
    func requireSupabaseClient() throws -> SupabaseClient {
        try requireClient()
    }

    private func requireClient() throws -> SupabaseClient {
        guard let client else {
            let msg = configurationFailureReason.isEmpty
                ? "Supabase n’est pas configuré."
                : configurationFailureReason
            throw SupabaseManagerError.notConfigured(reason: msg)
        }
        return client
    }

    /// Pour réconcilier l’état session avec `AuthManager`.
    func authStateChangesStream() -> AsyncStream<(event: AuthChangeEvent, session: Session?)>? {
        guard let client else { return nil }
        return client.auth.authStateChanges
    }

    func appUser(from user: User) -> AppUser {
        let meta = user.userMetadata
        let fullName = meta["full_name"]?.stringValue ?? meta["name"]?.stringValue
        let avatarString = meta["avatar_url"]?.stringValue ?? meta["picture"]?.stringValue
        return AppUser(
            id: user.id.uuidString,
            email: user.email,
            fullName: fullName,
            avatarURL: avatarString.flatMap(URL.init(string:))
        )
    }

    /// Utilisateur auth courant (pour métadonnées OAuth sans second fetch réseau inutile si déjà en session).
    func fetchAuthUser() async -> User? {
        guard let client = try? requireClient() else { return nil }
        do {
            let session = try await client.auth.session
            return session.user
        } catch {
            return nil
        }
    }

    /// Extrait prénom / nom / avatar depuis `user_metadata` (Google, etc.).
    func oauthHintsFromAuthUser(_ user: User) -> (firstName: String?, lastName: String?, avatarURL: String?) {
        let meta = user.userMetadata
        let keys = meta.keys.sorted().joined(separator: ", ")
        print("[GoogleProfile] metadata:", keys.isEmpty ? "(vide)" : keys)

        let given = Self.nonEmptyMetadataString(meta, "given_name", "first_name")
        let family = Self.nonEmptyMetadataString(meta, "family_name", "last_name")
        print("[GoogleProfile] given_name:", given ?? "nil")
        print("[GoogleProfile] family_name:", family ?? "nil")

        var first = given
        var last = family

        if first == nil || last == nil {
            if let full = Self.nonEmptyMetadataString(meta, "full_name", "name") {
                let split = Self.splitFullName(full)
                if first == nil || first?.isEmpty == true { first = split.first.isEmpty ? nil : split.first }
                if last == nil || last?.isEmpty == true { last = split.last.isEmpty ? nil : split.last }
            }
        }

        let avatar = Self.nonEmptyMetadataString(meta, "avatar_url", "picture")
        print("[GoogleProfile] avatar_url:", avatar ?? "nil")

        return (first, last, avatar)
    }

    /// Avatar OAuth sans logs (profil `profiles` incomplet ou fusion locale).
    func oauthAvatarURL(from user: User) -> String? {
        Self.nonEmptyMetadataString(user.userMetadata, "avatar_url", "picture")
    }

    private static func nonEmptyMetadataString(_ meta: [String: AnyJSON], _ keys: String...) -> String? {
        for key in keys {
            guard let raw = meta[key]?.stringValue else { continue }
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return nil
    }

    /// Premier segment = prénom, le reste = nom.
    private static func splitFullName(_ full: String) -> (first: String, last: String) {
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", "") }
        let parts = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let head = parts.first else { return ("", "") }
        let tail = parts.dropFirst().joined(separator: " ")
        return (head, tail)
    }

    // MARK: - Auth

    func signInWithApple(identityToken: String) async throws -> AppUser {
        let client = try requireClient()
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: identityToken)
        )
        return appUser(from: session.user)
    }

    /// OAuth Google (PKCE) : ouvre ``ASWebAuthenticationSession``, callback `amisa://login-callback`.
    @discardableResult
    func signInWithGoogleOAuth() async throws -> Session {
        print("[GoogleAuth] Supabase configured:", client != nil)

        let client = try requireClient()
        guard let redirectTo = URL(string: "amisa://login-callback") else {
            throw URLError(.badURL)
        }

        print("[GoogleAuth] Starting OAuth with redirect:", redirectTo.absoluteString)

        let session = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: redirectTo
        )

        #if DEBUG
        print("[GoogleAuth] OAuth terminé — user id=\(session.user.id.uuidString)")
        #endif

        return session
    }

    func sendMagicLink(email: String) async throws {
        let client = try requireClient()
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let redirectTo = URL(string: "amisa://login-callback") else {
            throw URLError(.badURL)
        }

        #if DEBUG
        print("[Supabase][MagicLink] email envoyé (OTP) : \(trimmed)")
        print("[Supabase][MagicLink] début signInWithOTP → redirectTo=\(redirectTo.absoluteString)")
        #endif

        do {
            try await client.auth.signInWithOTP(
                email: trimmed,
                redirectTo: redirectTo,
                shouldCreateUser: true
            )
            #if DEBUG
            print("[Supabase][MagicLink] succès signInWithOTP (email envoyé côté Supabase)")
            #endif
        } catch {
            #if DEBUG
            print("[Supabase][MagicLink] erreur Supabase : \(error)")
            if let le = error as? LocalizedError {
                print("[Supabase][MagicLink] erreur détaillée : \(le.errorDescription ?? "(sans description)")")
            }
            #endif
            throw error
        }
    }

    /// Complète le flux Magic Link / PKCE après ouverture du deep link.
    @discardableResult
    func finishMagicLink(from url: URL) async throws -> Session {
        let client = try requireClient()
        #if DEBUG
        print("[Supabase][DeepLink] début session(from:) URL=\(url.absoluteString)")
        #endif
        do {
            let session = try await client.auth.session(from: url)
            #if DEBUG
            print("[Supabase][DeepLink] succès session — user id=\(session.user.id.uuidString)")
            #endif
            return session
        } catch {
            #if DEBUG
            print("[Supabase][DeepLink] erreur session(from:) : \(error)")
            #endif
            throw error
        }
    }

    func fetchCurrentSessionUser() async throws -> AppUser {
        let client = try requireClient()
        let session = try await client.auth.session
        return appUser(from: session.user)
    }

    func signOut() async throws {
        guard let client else { return }
        try await client.auth.signOut()
    }

    // MARK: - Profiles & Storage

    func fetchProfile(userId: String) async -> UserProfile? {
        guard let client = try? requireClient() else { return nil }
        #if DEBUG
        print("[Profile] fetch userId=", userId)
        #endif

        do {
            let row: UserProfile = try await client.from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            #if DEBUG
            print("[Profile] loaded =", "\(row)")
            #endif
            return row
        } catch {
            #if DEBUG
            print("[Profile] loaded = nil (", error, ")")
            #endif
            return nil
        }
    }

    func upsertProfile(_ profile: UserProfile) async throws {
        let client = try requireClient()
        try await client.from("profiles")
            .upsert(profile, onConflict: "id")
            .execute()
        #if DEBUG
        print("[Profile] upsert success")
        #endif
    }

    func uploadProfileImage(imageData: Data, userId: String) async throws -> String {
        let client = try requireClient()
        let path = "\(userId)/avatar.jpg"
        try await client.storage.from("avatars").upload(
            path,
            data: imageData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        let url = try client.storage.from("avatars").getPublicURL(path: path)
        let s = url.absoluteString
        #if DEBUG
        print("[Profile] upload avatar success url=", s)
        #endif
        return s
    }

    func uploadBannerImage(imageData: Data, userId: String) async throws -> String {
        let client = try requireClient()
        let path = "\(userId)/banner.jpg"
        try await client.storage.from("banners").upload(
            path,
            data: imageData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        let url = try client.storage.from("banners").getPublicURL(path: path)
        let s = url.absoluteString
        #if DEBUG
        print("[Profile] upload banner success url=", s)
        #endif
        return s
    }
}
