//
//  DeleteAccountService.swift
//  Amisa
//
//  Suppression définitive du compte — conforme aux exigences Apple (in-app, sans e-mail support).
//

import Foundation

enum DeleteAccountError: LocalizedError {
    case notAuthenticated
    case supabaseNotConfigured
    case deletionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Tu dois être connecté pour supprimer ton compte."
        case .supabaseNotConfigured:
            return "Le service de compte n’est pas disponible pour le moment."
        case .deletionFailed(let error):
            if let le = error as? LocalizedError,
               let msg = le.errorDescription,
               !msg.isEmpty {
                return msg
            }
            return "La suppression du compte a échoué. Réessaie dans quelques instants."
        }
    }
}

@MainActor
final class DeleteAccountService {
    static let shared = DeleteAccountService()

    private init() {}

    /// Suppression immédiate : données Supabase, cache local, déconnexion.
    func deleteCurrentAccount() async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw DeleteAccountError.notAuthenticated
        }
        guard SupabaseManager.shared.isConfigured else {
            throw DeleteAccountError.supabaseNotConfigured
        }

        print("[DeleteAccount] start userId=\(userId)")

        await deleteStorageAssetsBestEffort(userId: userId)

        do {
            try await SupabaseManager.shared.deleteOwnAccount()
        } catch {
            print("[DeleteAccount] RPC failed:", error)
            throw DeleteAccountError.deletionFailed(error)
        }

        await clearLocalUserData()
        AuthManager.shared.resetAfterAccountDeletion()

        print("[DeleteAccount] completed")
    }

    private func deleteStorageAssetsBestEffort(userId: String) async {
        do {
            try await SupabaseManager.shared.deleteUserStorageAssets(userId: userId)
        } catch {
            print("[DeleteAccount] storage cleanup skipped:", error.localizedDescription)
        }
    }

    private func clearLocalUserData() async {
        FavoriteSearchService.shared.clearAll()
        SharedSearchSessionStore.shared.clear()
        await ProfileManager.shared.clear()
        ProfileStore.shared.clearAllForAccountDeletion()
        GuestSessionStore.shared.exitGuestMode()
    }
}
