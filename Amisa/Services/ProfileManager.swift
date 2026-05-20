//
//  ProfileManager.swift
//  Balibu
//
//  Profil Supabase ↔ cache local. Utilisateur connecté : Supabase est la source de vérité.
//

import Combine
import Foundation
import Supabase

@MainActor
final class ProfileManager: ObservableObject {

    static let shared = ProfileManager()

    @Published private(set) var profile: UserProfile?
    /// Plein écran obligatoire après auth si le profil DB est incomplet.
    @Published private(set) var needsMandatoryProfileCompletion = false
    /// Préremplissage `CompleteProfileView` (ligne `profiles` prime sur métadonnées OAuth).
    @Published private(set) var mandatoryProfilePrefill: MandatoryProfilePrefill?

    private init() {}

    // MARK: - Public API

    /// Après connexion (magic link, Apple, etc.).
    func syncAfterSignIn(user: AppUser) async {
        await refreshProfileFromServer(userId: user.id)
    }

    func refreshProfileFromServer(userId: String) async {
        guard SupabaseManager.shared.isConfigured else {
            needsMandatoryProfileCompletion = false
            mandatoryProfilePrefill = nil
            return
        }

        let row = await SupabaseManager.shared.fetchProfile(userId: userId)
        let authUser = await SupabaseManager.shared.fetchAuthUser()

        if let row {
            profile = row
            pushToProfileStore(row, oauthFallbackUser: authUser)
            needsMandatoryProfileCompletion = !row.isCompleteForMandatoryOnboarding
        } else {
            profile = nil
            needsMandatoryProfileCompletion = true
            mergeOAuthAvatarIntoProfileStore(from: authUser)
        }

        rebuildMandatoryPrefill(userId: userId, authUser: authUser)
    }

    func fetchProfile(userId: String) async {
        await refreshProfileFromServer(userId: userId)
    }

    func updateProfile(_ updated: UserProfile) async {
        do {
            try await SupabaseManager.shared.upsertProfile(updated)
            profile = updated
            let authUser = await SupabaseManager.shared.fetchAuthUser()
            pushToProfileStore(updated, oauthFallbackUser: authUser)
        } catch {
            #if DEBUG
            print("[Profile] upsert failed:", error)
            #endif
        }
    }

    /// Formulaire d’onboarding obligatoire : upload avatar best-effort puis upsert.
    func submitMandatoryProfile(
        userId: String,
        firstName: String,
        lastName: String,
        birthDate: Date,
        avatarJPEGData: Data?,
        fallbackAvatarURL: String?
    ) async throws {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFirst.isEmpty, !trimmedLast.isEmpty else {
            throw NSError(domain: "ProfileManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Prénom et nom sont obligatoires.",
            ])
        }

        var avatarURL = normalizedURLString(profile?.avatarURL)
        let bannerURL = profile?.bannerURL

        if let data = avatarJPEGData {
            if let url = try? await SupabaseManager.shared.uploadProfileImage(imageData: data, userId: userId) {
                avatarURL = url
            }
        } else if avatarURL == nil || avatarURL?.isEmpty == true {
            let fb = fallbackAvatarURL.flatMap { Self.normalizedNonEmpty($0) }
            if let fb {
                avatarURL = fb
            }
        }

        let row = UserProfile(
            id: userId,
            firstName: trimmedFirst,
            lastName: trimmedLast,
            birthDate: birthDate,
            avatarURL: avatarURL,
            bannerURL: bannerURL,
            createdAt: profile?.createdAt,
            updatedAt: Date()
        )

        try await SupabaseManager.shared.upsertProfile(row)
        profile = row
        let authUser = await SupabaseManager.shared.fetchAuthUser()
        pushToProfileStore(row, oauthFallbackUser: authUser)
        needsMandatoryProfileCompletion = false
        mandatoryProfilePrefill = nil
    }

    /// Efface le profil en mémoire (déconnexion).
    func clear() async {
        profile = nil
        needsMandatoryProfileCompletion = false
        mandatoryProfilePrefill = nil
    }

    // MARK: - Mandatory prefill

    private func rebuildMandatoryPrefill(userId: String, authUser: User?) {
        guard needsMandatoryProfileCompletion else {
            mandatoryProfilePrefill = nil
            return
        }

        let dbFirst = Self.normalizedNonEmpty(profile?.firstName)
        let dbLast = Self.normalizedNonEmpty(profile?.lastName)
        let dbAvatar = normalizedURLString(profile?.avatarURL)

        let hints = authUser.map { SupabaseManager.shared.oauthHintsFromAuthUser($0) }

        let mergedFirst = dbFirst ?? hints?.firstName.flatMap(Self.normalizedNonEmpty) ?? ""
        let mergedLast = dbLast ?? hints?.lastName.flatMap(Self.normalizedNonEmpty) ?? ""
        let mergedAvatar = dbAvatar ?? hints?.avatarURL.flatMap(Self.normalizedNonEmpty)

        let hideNames = !mergedFirst.isEmpty && !mergedLast.isEmpty

        mandatoryProfilePrefill = MandatoryProfilePrefill(
            suggestedFirstName: mergedFirst,
            suggestedLastName: mergedLast,
            avatarRemoteURL: mergedAvatar,
            hideNameFields: hideNames,
            fallbackAvatarURLForUpsert: mergedAvatar
        )

        print("[Amisa][CompleteProfile] prefilled from provider — userId=\(userId) hideNameFields=\(hideNames) hasAvatarURL=\(mergedAvatar != nil)")
    }

    private func mergeOAuthAvatarIntoProfileStore(from authUser: User?) {
        guard let raw = authUser.flatMap({ SupabaseManager.shared.oauthAvatarURL(from: $0) }).flatMap(Self.normalizedNonEmpty) else { return }
        ProfileStore.shared.mergeAvatarRemoteURLIfAbsent(raw)
    }

    private static func normalizedNonEmpty(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func normalizedURLString(_ raw: String?) -> String? {
        Self.normalizedNonEmpty(raw)
    }

    // MARK: - Private

    private func pushToProfileStore(_ p: UserProfile, oauthFallbackUser: User?) {
        let store = ProfileStore.shared
        let dbAvatar = normalizedURLString(p.avatarURL)
        let oauthAvatar = oauthFallbackUser.flatMap { SupabaseManager.shared.oauthAvatarURL(from: $0) }.flatMap(Self.normalizedNonEmpty)
        let resolvedAvatar = dbAvatar ?? oauthAvatar ?? normalizedURLString(store.avatarRemoteURLString)

        store.save(
            firstName: p.firstName ?? "",
            lastName: p.lastName ?? "",
            avatarFileName: store.avatarFileName,
            bannerFileName: store.bannerFileName,
            avatarRemoteURL: resolvedAvatar,
            bannerRemoteURL: normalizedURLString(p.bannerURL),
            mergeRemoteURLs: true
        )
    }
}
