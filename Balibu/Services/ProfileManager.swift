//
//  ProfileManager.swift
//  Balibu
//
//  Synchronise le profil Supabase ↔ ProfileStore local.
//  Appelé par AuthManager après chaque connexion réussie.
//

import Combine
import Foundation

@MainActor
final class ProfileManager: ObservableObject {

    static let shared = ProfileManager()

    @Published private(set) var profile: UserProfile?

    private init() {}

    // MARK: - Public API

    /// Appelé immédiatement après une connexion réussie.
    func syncAfterSignIn(user: AppUser) async {
        if let existing = try? await SupabaseManager.shared.fetchProfile(userId: user.id) {
            profile = existing
            pushToProfileStore(existing)
        } else {
            await createProfile(for: user)
        }
    }

    /// Récupère le profil depuis Supabase et met à jour l'état local.
    func fetchProfile(userId: String) async {
        if let fetched = try? await SupabaseManager.shared.fetchProfile(userId: userId) {
            profile = fetched
            pushToProfileStore(fetched)
        }
    }

    /// Met à jour le profil côté Supabase et en local.
    func updateProfile(_ updated: UserProfile) async {
        try? await SupabaseManager.shared.upsertProfile(updated)
        profile = updated
        pushToProfileStore(updated)
    }

    /// Efface le profil en mémoire (déconnexion).
    func clear() async {
        profile = nil
    }

    // MARK: - Private

    private func createProfile(for user: AppUser) async {
        let parts   = user.fullName?.components(separatedBy: " ") ?? []
        let first   = parts.first
        let last    = parts.dropFirst().joined(separator: " ")

        let new = UserProfile(
            id:         user.id,
            firstName:  first,
            lastName:   last.isEmpty ? nil : last,
            fullName:   user.fullName,
            avatarURL:  user.avatarURL?.absoluteString,
            email:      user.email,
            createdAt:  Date(),
            updatedAt:  Date()
        )
        try? await SupabaseManager.shared.upsertProfile(new)
        profile = new
        pushToProfileStore(new)
    }

    /// Reflète le profil Supabase dans le ProfileStore local (utilisé par EditProfileView).
    private func pushToProfileStore(_ p: UserProfile) {
        ProfileStore.shared.save(
            firstName:      p.firstName  ?? "",
            lastName:       p.lastName   ?? "",
            avatarFileName: nil   // TODO: télécharger avatarURL si présent et sauvegarder via ImagePersistenceService
        )
    }
}
