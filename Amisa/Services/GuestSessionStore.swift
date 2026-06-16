//
//  GuestSessionStore.swift
//  Amisa
//
//  Session invitée locale — accès app sans compte Supabase.
//

import Combine
import Foundation

@MainActor
final class GuestSessionStore: ObservableObject {
    static let shared = GuestSessionStore()

    static let storageKey = "amisa.isGuest"

    @Published private(set) var isGuest: Bool

    private init() {
        isGuest = UserDefaults.standard.bool(forKey: Self.storageKey)
    }

    /// Favoris et sync cloud réservés aux comptes connectés.
    var canUseCloudFeatures: Bool {
        AuthManager.shared.isAuthenticated
    }

    /// Accès principal à l’app après onboarding.
    var hasAppAccess: Bool {
        AuthManager.shared.isAuthenticated || isGuest
    }

    func enterGuestMode() {
        guard !isGuest else { return }
        isGuest = true
        UserDefaults.standard.set(true, forKey: Self.storageKey)
        #if DEBUG
        print("[GuestSession] entered guest mode")
        #endif
    }

    func exitGuestMode() {
        guard isGuest else { return }
        isGuest = false
        UserDefaults.standard.set(false, forKey: Self.storageKey)
        #if DEBUG
        print("[GuestSession] exited guest mode")
        #endif
    }
}
