//
//  AmisaAuthRedirect.swift
//  Amisa
//
//  Deep link OAuth Supabase (Google, reset password).
//

import Foundation

enum AmisaAuthRedirect {
    static let scheme = "amisa"
    static let host = "auth-callback"
    static let bundleURLIdentifier = "io.flowerz.Amisa.app"

    /// URL passée à `signInWithOAuth` / `resetPasswordForEmail`.
    static var callbackURL: URL {
        URL(string: "\(scheme)://\(host)")!
    }

    /// Hôtes acceptés pour le retour OAuth (auth-callback uniquement).
    private static let acceptedHosts: Set<String> = [host]

    static func isAuthCallback(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == scheme else { return false }
        let h = (url.host ?? "").lowercased()
        return acceptedHosts.contains(h)
    }
}
