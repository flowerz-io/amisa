//
//  MarketplaceSource.swift
//  Balibu
//
//  Libellés et devises par défaut par source API (extensible sans coupler la vue).
//

import Foundation

/// Espace de noms pour l’affichage des marketplaces (pas de enum fermée : nouvelles sources = chaîne backend).
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

    /// Libellé badge : chaîne API ou nom canon pour les sources connues ; sinon texte tel quel.
    static func displayLabel(from raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return String(localized: "Marketplace") }
        switch normalizedSource(t) {
        case "vinted": return "Vinted"
        case "grailed": return "Grailed"
        case "le bon coin", "leboncoin": return "Le Bon Coin"
        case "ebay": return "eBay"
        case "depop": return "Depop"
        case "facebook marketplace", "facebookmarketplace": return "Facebook Marketplace"
        default: return t
        }
    }

    /// Devise par défaut si le JSON n’en fournit pas (EUR Europe / USD Grailed).
    static func defaultCurrencyCode(forSource raw: String) -> String {
        switch normalizedSource(raw) {
        case "grailed": return "USD"
        case "vinted": return "EUR"
        default: return "EUR"
        }
    }

    /// Nom d’asset image (logo PNG) associé à une source provider.
    /// Retourne nil si source inconnue.
    static func logoAssetName(from raw: String) -> String? {
        switch normalizedSource(raw) {
        case "vinted": return "provider_vinted"
        case "grailed": return "provider_grailed"
        case "le bon coin", "leboncoin": return "provider_leboncoin"
        case "ebay": return "provider_ebay"
        case "depop": return "provider_depop"
        case "facebook marketplace", "facebookmarketplace": return "provider_facebookmarketplace"
        default: return nil
        }
    }

    static func providerLogoAssetName(for raw: String) -> String? {
        logoAssetName(from: raw)
    }

    /// Clé canonique stable pour les filtres UI et comparaisons.
    static func canonicalKey(from raw: String) -> String {
        switch normalizedSource(raw) {
        case "vinted": return "vinted"
        case "grailed": return "grailed"
        case "le bon coin", "leboncoin": return "leboncoin"
        case "ebay": return "ebay"
        case "depop": return "depop"
        case "facebook marketplace", "facebookmarketplace": return "facebookmarketplace"
        default:
            return normalizedSource(raw).replacingOccurrences(of: " ", with: "")
        }
    }

    /// Providers affichables dans le filtre Marketplace (préparé pour extension).
    static let knownProviderDisplayNames: [String] = [
        "Vinted",
        "Grailed",
        "eBay",
        "Le Bon Coin",
        "Depop",
        "Facebook Marketplace",
    ]
}
