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
//
// Table SQL à créer dans Supabase :
//
// create table profiles (
//   id          uuid primary key references auth.users(id) on delete cascade,
//   first_name  text,
//   last_name   text,
//   full_name   text,
//   avatar_url  text,
//   email       text,
//   created_at  timestamptz default now(),
//   updated_at  timestamptz default now()
// );
//
// Activer Row Level Security :
//   alter table profiles enable row level security;
//   create policy "Users manage own profile"
//     on profiles for all using (auth.uid() = id);

struct UserProfile: Codable, Identifiable, Equatable {
    let id: String
    var firstName: String?
    var lastName: String?
    var fullName: String?
    var avatarURL: String?
    var email: String?
    let createdAt: Date?
    var updatedAt: Date?

    var displayName: String {
        if let full = fullName, !full.isEmpty { return full }
        let parts = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? (email ?? String(localized: "Utilisateur")) : parts.joined(separator: " ")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName  = "first_name"
        case lastName   = "last_name"
        case fullName   = "full_name"
        case avatarURL  = "avatar_url"
        case email
        case createdAt  = "created_at"
        case updatedAt  = "updated_at"
    }
}
