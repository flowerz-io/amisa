import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published var firstName: String
    @Published var lastName: String
    @Published var avatarFileName: String?
    @Published var bannerFileName: String?
    /// URLs publiques Supabase (affichage si pas d’image locale).
    @Published var avatarRemoteURLString: String?
    @Published var bannerRemoteURLString: String?

    private let firstKey = "amisa.profile.firstName"
    private let lastKey = "amisa.profile.lastName"
    private let avatarKey = "amisa.profile.avatarFileName"
    private let bannerKey = "amisa.profile.bannerFileName"
    private let avatarRemoteKey = "amisa.profile.avatarRemoteURL"
    private let bannerRemoteKey = "amisa.profile.bannerRemoteURL"

    private init() {
        let d = UserDefaults.standard
        firstName = d.string(forKey: firstKey) ?? ""
        lastName = d.string(forKey: lastKey) ?? ""
        avatarFileName = d.string(forKey: avatarKey)
        bannerFileName = d.string(forKey: bannerKey)
        avatarRemoteURLString = d.string(forKey: avatarRemoteKey)
        bannerRemoteURLString = d.string(forKey: bannerRemoteKey)
    }

    var displayName: String {
        let f = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if f.isEmpty && l.isEmpty { return String(localized: "Utilisateur") }
        if l.isEmpty { return f }
        if f.isEmpty { return l }
        return "\(f) \(l)"
    }

    /// Sauvegarde locale + URLs distantes optionnelles (`mergeRemoteURLs` met à jour les URLs Supabase persistées).
    func save(
        firstName: String,
        lastName: String,
        avatarFileName: String?,
        bannerFileName: String?,
        avatarRemoteURL: String? = nil,
        bannerRemoteURL: String? = nil,
        mergeRemoteURLs: Bool = false
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.avatarFileName = avatarFileName
        self.bannerFileName = bannerFileName

        let d = UserDefaults.standard
        d.set(firstName, forKey: firstKey)
        d.set(lastName, forKey: lastKey)
        if let avatarFileName {
            d.set(avatarFileName, forKey: avatarKey)
        } else {
            d.removeObject(forKey: avatarKey)
        }
        if let bannerFileName {
            d.set(bannerFileName, forKey: bannerKey)
        } else {
            d.removeObject(forKey: bannerKey)
        }

        if mergeRemoteURLs {
            let av = avatarRemoteURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.avatarRemoteURLString = (av?.isEmpty == false) ? av : nil
            let bn = bannerRemoteURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.bannerRemoteURLString = (bn?.isEmpty == false) ? bn : nil

            if let a = self.avatarRemoteURLString {
                d.set(a, forKey: avatarRemoteKey)
            } else {
                d.removeObject(forKey: avatarRemoteKey)
            }
            if let b = self.bannerRemoteURLString {
                d.set(b, forKey: bannerRemoteKey)
            } else {
                d.removeObject(forKey: bannerRemoteKey)
            }
        }
    }

    /// N’écrit pas par-dessus une URL déjà persistée (priorité profil / cache local).
    func mergeAvatarRemoteURLIfAbsent(_ url: String) {
        let t = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if let existing = avatarRemoteURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !existing.isEmpty {
            return
        }
        avatarRemoteURLString = t
        UserDefaults.standard.set(t, forKey: avatarRemoteKey)
    }

    /// Réinitialise uniquement les URLs distantes (ex. déconnexion tout en gardant prénom/nom locaux).
    func clearSupabaseRemoteOverlay() {
        avatarRemoteURLString = nil
        bannerRemoteURLString = nil
        let d = UserDefaults.standard
        d.removeObject(forKey: avatarRemoteKey)
        d.removeObject(forKey: bannerRemoteKey)
    }

    func avatarImage() -> UIImage? {
        guard let name = avatarFileName else { return nil }
        return ImagePersistenceService.shared.loadUIImage(fileName: name)
    }

    func bannerImage() -> UIImage? {
        guard let name = bannerFileName else { return nil }
        return ImagePersistenceService.shared.loadUIImage(fileName: name)
    }
}
