//
//  SupabaseConfig.swift
//  Amisa
//
//  Clés lues uniquement depuis Info.plist du target Amisa (`Bundle.main`) :
//  SUPABASE_URL, SUPABASE_ANON_KEY.
//

import Foundation

enum SupabaseConfig {
    /// Clés dans `Amisa/Info.plist` — pointé par `INFOPLIST_FILE = Amisa/Info.plist` sur le target Amisa.
    static let plistURLKey = "SUPABASE_URL"
    static let plistAnonKeyKey = "SUPABASE_ANON_KEY"

    /// URL officielle du projet (référence uniquement ; aucune valeur de secours dans le code).
    static let officialSupabaseURL = "https://istsqscnkkfbyygkgozt.supabase.co"

    /// Marqueur de l’ancienne URL erronée (`…byyygk…` au lieu de `…byygk…`).
    static let legacyWrongSupabaseURLMarker = "byyyg"

    /// Trim espaces / fins de ligne / BOM ; pas de logique métier.
    static func normalizeCredential(_ raw: String?) -> String {
        guard let raw else { return "" }
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "\u{FEFF}", with: "")
        return s
    }
}
