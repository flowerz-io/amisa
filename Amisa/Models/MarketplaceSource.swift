//
//  MarketplaceSource.swift
//  Balibu
//
//  Amisa est centré Vinted ; autres chaînes restent tolérées pour données historiques.
//

import Foundation

enum MarketplaceSource {
    private static func normalizedSource(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "’", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func displayLabel(from raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "Vinted" }
        switch normalizedSource(t) {
        case "vinted": return "Vinted"
        default: return t
        }
    }

    static func defaultCurrencyCode(forSource raw: String) -> String {
        "EUR"
    }

    static func logoAssetName(from raw: String) -> String? {
        switch normalizedSource(raw) {
        case "vinted": return "provider_vinted"
        default: return nil
        }
    }

    static func providerLogoAssetName(for raw: String) -> String? {
        logoAssetName(from: raw)
    }

    static func canonicalKey(from raw: String) -> String {
        switch normalizedSource(raw) {
        case "vinted": return "vinted"
        default:
            return normalizedSource(raw).replacingOccurrences(of: " ", with: "")
        }
    }

    static let knownProviderDisplayNames: [String] = ["Vinted"]
}
