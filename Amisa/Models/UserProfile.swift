//
//  UserProfile.swift
//  Balibu
//
//  Modèle utilisateur — reflète la table `profiles` Supabase.
//

import Foundation

// MARK: - AppUser (session active)

struct AppUser: Equatable {
    let id: String
    let email: String?
    let fullName: String?
    let avatarURL: URL?

    var displayName: String {
        if let name = fullName, !name.isEmpty { return name }
        return email ?? String(localized: "Utilisateur")
    }

    var initials: String {
        let words = displayName.split(separator: " ").prefix(2)
        return words.compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }
}

// MARK: - UserProfile (table `profiles`)

struct UserProfile: Codable, Identifiable, Equatable {
    let id: String
    var firstName: String?
    var lastName: String?
    var birthDate: Date?
    var avatarURL: String?
    var bannerURL: String?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case birthDate = "birth_date"
        case avatarURL = "avatar_url"
        case bannerURL = "banner_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    private static let sqlDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func decodeTimestamptz(_ value: String) -> Date? {
        if let d = isoFractional.date(from: value) { return d }
        if let d = isoPlain.date(from: value) { return d }
        return sqlDayFormatter.date(from: String(value.prefix(10)))
    }

    init(
        id: String,
        firstName: String?,
        lastName: String?,
        birthDate: Date?,
        avatarURL: String?,
        bannerURL: String?,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.birthDate = birthDate
        self.avatarURL = avatarURL
        self.bannerURL = bannerURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        avatarURL = try c.decodeIfPresent(String.self, forKey: .avatarURL)
        bannerURL = try c.decodeIfPresent(String.self, forKey: .bannerURL)

        if let day = try c.decodeIfPresent(String.self, forKey: .birthDate), !day.isEmpty {
            birthDate = Self.sqlDayFormatter.date(from: day)
        } else {
            birthDate = nil
        }

        if let ca = try c.decodeIfPresent(String.self, forKey: .createdAt), !ca.isEmpty {
            createdAt = Self.decodeTimestamptz(ca)
        } else {
            createdAt = nil
        }

        if let ua = try c.decodeIfPresent(String.self, forKey: .updatedAt), !ua.isEmpty {
            updatedAt = Self.decodeTimestamptz(ua)
        } else {
            updatedAt = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(firstName, forKey: .firstName)
        try c.encodeIfPresent(lastName, forKey: .lastName)
        try c.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try c.encodeIfPresent(bannerURL, forKey: .bannerURL)

        if let birthDate {
            try c.encode(Self.sqlDayFormatter.string(from: birthDate), forKey: .birthDate)
        }

        let now = Date()
        let upd = updatedAt ?? now
        try c.encode(Self.isoPlain.string(from: upd), forKey: .updatedAt)

        if let createdAt {
            try c.encode(Self.isoPlain.string(from: createdAt), forKey: .createdAt)
        }
    }

    /// Étape d’onboarding obligatoire : prénom, nom, date de naissance.
    var isCompleteForMandatoryOnboarding: Bool {
        let f = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let l = lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !f.isEmpty, !l.isEmpty, birthDate != nil else { return false }
        return true
    }

    var displayName: String {
        let parts = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? String(localized: "Utilisateur") : parts.joined(separator: " ")
    }
}

// MARK: - Préremplissage onboarding (profil incomplet)

/// Proposition pour `CompleteProfileView` : la ligne `profiles` Supabase prime sur les métadonnées OAuth.
struct MandatoryProfilePrefill: Equatable {
    var suggestedFirstName: String
    var suggestedLastName: String
    /// Affichage (AsyncImage / aperçu).
    var avatarRemoteURL: String?
    /// Prénom + nom déjà connus (BD ou Google) : pas de champs de saisie.
    var hideNameFields: Bool
    /// À écrire dans `profiles.avatar_url` si l’utilisateur n’envoie pas de fichier (ex. `picture` Google).
    var fallbackAvatarURLForUpsert: String?
}
