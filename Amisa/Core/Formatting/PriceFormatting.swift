//
//  PriceFormatting.swift
//  Balibu
//
//  Prix style français : 17,50 € ou 202,00 $ (2 décimales, symbole à droite).
//

import Foundation

enum PriceFormatting {
    private static let localeFR = Locale(identifier: "fr_FR")
    private static let localeUS = Locale(identifier: "en_US_POSIX")

    /// Prix catalogue : nombre > 0, sinon "—". Devise ISO ou repli selon la source.
    static func formatListingPrice(amount: Double, currencyCode: String?, fallbackCurrencyCode: String) -> String {
        formatMarketplacePrice(amount: amount, currencyCode: currencyCode, fallbackCurrencyCode: fallbackCurrencyCode)
    }

    /// Format unifié marketplace, sans afficher les codes EUR/USD/GBP en texte brut.
    static func formatMarketplacePrice(amount: Double, currencyCode: String?, fallbackCurrencyCode: String) -> String {
        guard amount.isFinite, amount > 0 else { return "—" }

        let code = normalizedCurrencyCode(currencyCode) ?? fallbackCurrencyCode.uppercased()
        let locale = (code == "EUR") ? localeFR : localeUS

        let nf = NumberFormatter()
        nf.locale = locale
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2

        let numStr: String
        if let s = nf.string(from: NSNumber(value: amount)) {
            numStr = s
        } else {
            let fallback = String(format: "%.2f", amount)
            numStr = (code == "EUR") ? fallback.replacingOccurrences(of: ".", with: ",") : fallback
        }

        switch code {
        case "EUR":
            return numStr + "\u{00A0}€"
        case "USD":
            return "$" + numStr
        case "GBP":
            return "£" + numStr
        default:
            return numStr + symbolSuffix(for: code)
        }
    }

    private static func normalizedCurrencyCode(_ raw: String?) -> String? {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return nil }
        let u = r.uppercased()
        guard u.count == 3, u.allSatisfy({ $0.isLetter }) else { return nil }
        return u
    }

    /// Symbole ou code à droite, avec espace fin (usage FR).
    private static func symbolSuffix(for currencyCode: String) -> String {
        switch currencyCode.uppercased() {
        case "EUR": return "\u{00A0}€"
        case "USD": return "\u{00A0}$"
        case "GBP": return "\u{00A0}£"
        case "CHF": return "\u{00A0}CHF"
        default: return "\u{00A0}\(currencyCode.uppercased())"
        }
    }
}
