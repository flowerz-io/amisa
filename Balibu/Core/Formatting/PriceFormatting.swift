//
//  PriceFormatting.swift
//  Balibu
//
//  Affichage des prix style français : 17,50 € (2 décimales, symbole à droite).
//

import Foundation

enum PriceFormatting {
    /// Locale fixe FR pour séparateur décimal et position du symbole (€ à droite).
    private static let localeFR = Locale(identifier: "fr_FR")

    static func formatCurrency(amount: Double, currencyCode: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = localeFR
        formatter.currencyCode = currencyCode ?? "EUR"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        if let s = formatter.string(from: NSNumber(value: amount)) {
            return s
        }
        let n = String(format: "%.2f", amount).replacingOccurrences(of: ".", with: ",")
        return "\(n) €"
    }
}
