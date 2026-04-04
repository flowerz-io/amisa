//
//  MarketplaceSource.swift
//  Balibu
//
//  Libellés et devises par défaut par source API (extensible sans coupler la vue).
//

import Foundation

/// Espace de noms pour l’affichage des marketplaces (pas de enum fermée : nouvelles sources = chaîne backend).
enum MarketplaceSource {
    /// Libellé badge : chaîne API ou nom canon pour les sources connues ; sinon texte tel quel.
    static func displayLabel(from raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return String(localized: "Marketplace") }
        switch t.lowercased() {
        case "vinted": return "Vinted"
        case "grailed": return "Grailed"
        default: return t
        }
    }

    /// Devise par défaut si le JSON n’en fournit pas (EUR Europe / USD Grailed).
    static func defaultCurrencyCode(forSource raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "grailed": return "USD"
        case "vinted": return "EUR"
        default: return "EUR"
        }
    }
}
