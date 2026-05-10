//
//  SupabaseManager.swift
//  Balibu
//
//  Couche d'accès Supabase.
//  Actuellement : stubs compilables sans le SDK.
//  Une fois le SDK installé, décommenter les blocs marqués TODO.
//

import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Configuration
// ─────────────────────────────────────────────────────────────────────────────
//
// ÉTAPE 1 — Installer le SDK Supabase Swift via SPM :
//   Xcode → File → Add Package Dependencies
//   URL : https://github.com/supabase/supabase-swift
//   Version : 2.x (Up to Next Major)
//
// ÉTAPE 2 — Remplacer les valeurs ci-dessous par tes vraies clés Supabase :
//   Tableau de bord : https://app.supabase.com → Project Settings → API
//   - Project URL    → SUPABASE_URL
//   - anon / public  → SUPABASE_ANON_KEY
//
// ⚠️  NE JAMAIS hardcoder le service_role key dans l'app cliente.
// ─────────────────────────────────────────────────────────────────────────────

enum SupabaseConfig {
    // TODO: Remplacer par ton URL de projet (ex. https://xyzabc.supabase.co)
    static let url    = "https://YOUR_PROJECT_ID.supabase.co"
    // TODO: Remplacer par ta clé publique (anon)
    static let anonKey = "YOUR_SUPABASE_ANON_KEY"
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SupabaseManager
// ─────────────────────────────────────────────────────────────────────────────
//
// Après installation du SDK, ajouter en tête de fichier :
//
//   import Supabase
//
// Puis décommenter l'instance client :
//
//   private let client = SupabaseClient(
//       supabaseURL: URL(string: SupabaseConfig.url)!,
//       supabaseKey: SupabaseConfig.anonKey
//   )
//
// et remplacer chaque corps de méthode par le vrai appel Supabase.
// ─────────────────────────────────────────────────────────────────────────────

final class SupabaseManager {
    static let shared = SupabaseManager()
    private init() {}

    // MARK: - Auth

    /// Apple Sign In — passe l'identityToken JWT d'Apple à Supabase.
    func signInWithApple(identityToken: String) async throws -> AppUser {
        // TODO:
        // let session = try await client.auth.signInWithIdToken(
        //     credentials: .init(provider: .apple, idToken: identityToken)
        // )
        // return AppUser(from: session.user)
        return AppUser(id: UUID().uuidString, email: nil, fullName: nil, avatarURL: nil)
    }

    /// Google Sign In — passe idToken + accessToken de Google à Supabase.
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> AppUser {
        // TODO:
        // let session = try await client.auth.signInWithIdToken(
        //     credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
        // )
        // return AppUser(from: session.user)
        return AppUser(id: UUID().uuidString, email: nil, fullName: nil, avatarURL: nil)
    }

    /// Magic link — Supabase envoie un email de connexion.
    func sendMagicLink(email: String) async throws {
        // TODO:
        // try await client.auth.signInWithOTP(email: email)
        //
        // Configurer le redirect URL dans Supabase Dashboard :
        //   Authentication → URL Configuration → Redirect URLs
        //   Ajouter : balibu://auth/callback
        //
        // Dans BalibuApp.swift, gérer le deep link :
        //   .onOpenURL { url in
        //       Task { try? await supabaseClient.auth.session(from: url) }
        //   }
    }

    func signOut() async throws {
        // TODO: try await client.auth.signOut()
    }

    // MARK: - Profiles

    func fetchProfile(userId: String) async throws -> UserProfile? {
        // TODO:
        // return try await client
        //     .from("profiles")
        //     .select()
        //     .eq("id", value: userId)
        //     .single()
        //     .execute()
        //     .value
        return nil
    }

    func upsertProfile(_ profile: UserProfile) async throws {
        // TODO:
        // try await client
        //     .from("profiles")
        //     .upsert(profile, onConflict: "id")
        //     .execute()
    }
}
