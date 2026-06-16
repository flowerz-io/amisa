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

    private static let pendingGenderKey = "amisa.pending.gender"
    private static let pendingCountryKey = "amisa.pending.country"

    @Published private(set) var profile: UserProfile?
    /// Plein écran obligatoire après auth si le profil DB est incomplet.
    @Published private(set) var needsMandatoryProfileCompletion = false
    /// Préremplissage `CompleteProfileView` (ligne `profiles` prime sur métadonnées OAuth).
    @Published private(set) var mandatoryProfilePrefill: MandatoryProfilePrefill?

    private init() {}

    // MARK: - Public API

    /// Après connexion (Apple, Google, e-mail, etc.).
    func syncAfterSignIn(user: AppUser) async {
        await refreshProfileFromServer(userId: user.id)
        await flushPendingOnboardingFields(userId: user.id)
    }

    func refreshProfileFromServer(userId: String) async {
        guard SupabaseManager.shared.isConfigured else {
            needsMandatoryProfileCompletion = false
            mandatoryProfilePrefill = nil
            return
        }

        let authUser = await SupabaseManager.shared.fetchAuthUser()
        var row = await SupabaseManager.shared.fetchProfile(userId: userId)

        if row == nil, let authUser {
            row = await ensureProfileRow(userId: userId, authUser: authUser)
        }

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
        var row = updated
        row.applyComputedDisplayName()
        row.updatedAt = Date()

        do {
            try await SupabaseManager.shared.upsertProfile(row)
            profile = row
            let authUser = await SupabaseManager.shared.fetchAuthUser()
            pushToProfileStore(row, oauthFallbackUser: authUser)
        } catch {
            #if DEBUG
            print("[Profile] upsert failed:", error)
            #endif
        }
    }

    /// Sélection onboarding genre — persistance locale + Supabase si connecté.
    func persistOnboardingGender(_ gender: String) async {
        guard let stored = Self.normalizedGenderForStorage(gender) else { return }
        UserDefaults.standard.set(stored, forKey: Self.pendingGenderKey)

        guard let userId = AuthManager.shared.currentUser?.id else { return }
        await mergeProfile(userId: userId) { row in
            row.gender = stored
        }
    }

    /// Sélection onboarding pays — persistance locale + Supabase si connecté.
    func persistOnboardingCountry(_ country: String?) async {
        if let country, !country.isEmpty {
            UserDefaults.standard.set(country, forKey: Self.pendingCountryKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.pendingCountryKey)
        }

        guard let userId = AuthManager.shared.currentUser?.id else { return }
        await mergeProfile(userId: userId) { row in
            row.country = country?.isEmpty == true ? nil : country
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

        var row = UserProfile(
            id: userId,
            firstName: trimmedFirst,
            lastName: trimmedLast,
            birthDate: birthDate,
            gender: profile?.gender ?? pendingGender(),
            country: profile?.country ?? pendingCountry(),
            avatarURL: avatarURL,
            bannerURL: bannerURL,
            createdAt: profile?.createdAt,
            updatedAt: Date()
        )
        row.applyComputedDisplayName()

        try await SupabaseManager.shared.upsertProfile(row)
        profile = row
        let authUser = await SupabaseManager.shared.fetchAuthUser()
        pushToProfileStore(row, oauthFallbackUser: authUser)
        needsMandatoryProfileCompletion = false
        mandatoryProfilePrefill = nil
        clearPendingOnboardingFields()
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

    // MARK: - Profile row lifecycle

    private func ensureProfileRow(userId: String, authUser: User) async -> UserProfile? {
        let hints = SupabaseManager.shared.oauthHintsFromAuthUser(authUser)
        var row = UserProfile(
            id: userId,
            firstName: hints.firstName,
            lastName: hints.lastName,
            gender: pendingGender(),
            country: pendingCountry(),
            avatarURL: hints.avatarURL,
            createdAt: Date(),
            updatedAt: Date()
        )
        row.applyComputedDisplayName()

        do {
            try await SupabaseManager.shared.upsertProfile(row)
            #if DEBUG
            print("[Profile] created initial row for userId=", userId)
            #endif
            return row
        } catch {
            #if DEBUG
            print("[Profile] create initial row failed:", error)
            #endif
            return nil
        }
    }

    private func mergeProfile(userId: String, mutate: (inout UserProfile) -> Void) async {
        var base = profile?.id == userId ? profile : nil
        if base == nil {
            base = await SupabaseManager.shared.fetchProfile(userId: userId)
        }

        var row: UserProfile
        if var existing = base {
            mutate(&existing)
            row = existing
        } else if let authUser = await SupabaseManager.shared.fetchAuthUser() {
            guard let created = await ensureProfileRow(userId: userId, authUser: authUser) else { return }
            var patched = created
            mutate(&patched)
            row = patched
        } else {
            row = UserProfile(
                id: userId,
                gender: pendingGender(),
                country: pendingCountry(),
                createdAt: Date(),
                updatedAt: Date()
            )
            mutate(&row)
        }

        row.updatedAt = Date()
        row.applyComputedDisplayName()
        await updateProfile(row)
    }

    private func flushPendingOnboardingFields(userId: String) async {
        let gender = pendingGender()
        let country = pendingCountry()
        guard gender != nil || country != nil else { return }

        await mergeProfile(userId: userId) { row in
            if let gender { row.gender = gender }
            if let country { row.country = country }
        }
    }

    private func pendingGender() -> String? {
        Self.normalizedGenderForStorage(UserDefaults.standard.string(forKey: Self.pendingGenderKey))
    }

    private func pendingCountry() -> String? {
        Self.normalizedNonEmpty(UserDefaults.standard.string(forKey: Self.pendingCountryKey))
    }

    private func clearPendingOnboardingFields() {
        UserDefaults.standard.removeObject(forKey: Self.pendingGenderKey)
        UserDefaults.standard.removeObject(forKey: Self.pendingCountryKey)
    }

    /// Valeurs acceptées par `profiles.gender` : female | male | other.
    static func normalizedGenderForStorage(_ raw: String?) -> String? {
        guard let raw else { return nil }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "femme", "female", "f", "woman", "women": return "female"
        case "homme", "male", "m", "man", "men": return "male"
        case "other", "autre", "non-binary", "non_binary", "nb": return "other"
        default: return nil
        }
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

        let first = p.firstName ?? ""
        let last = p.lastName ?? ""

        store.save(
            firstName: first,
            lastName: last,
            avatarFileName: store.avatarFileName,
            bannerFileName: store.bannerFileName,
            avatarRemoteURL: resolvedAvatar,
            bannerRemoteURL: normalizedURLString(p.bannerURL),
            mergeRemoteURLs: true
        )
    }
}
