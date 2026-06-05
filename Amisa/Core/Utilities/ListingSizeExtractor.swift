//
//  ListingSizeExtractor.swift
//  Amisa
//
//  Résolution taille annonce : champ API + fallback titre.
//

import Foundation

enum ListingSizeExtractor {
    /// Taille affichable : valeur API normalisée, extraction titre, ou `NS`.
    static func resolvedLabel(size: String?, title: String) -> String {
        if let normalized = normalizedSize(from: size) {
            return normalized
        }
        if let raw = size?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }
        if let fromTitle = extractFromTitle(title) {
            return fromTitle
        }
        return "NS"
    }

    static func normalizedSize(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if matches(trimmed, pattern: #"(?i)\b(one\s*size|taille\s*unique|unique|tu|os)\b"#) {
            return "OS"
        }

        let upper = trimmed.uppercased()
        if upper == "TU" { return "OS" }
        if upper == "OS" { return upper }
        if upper == "NS" { return nil }

        if let frac = firstMatch(in: trimmed, pattern: #"\b(3[5-9]|4[0-8])\s+([12])\s*/\s*([23])\b"#) {
            return "\(frac[1]) \(frac[2])/\(frac[3])"
        }

        if let dec = firstMatch(in: trimmed, pattern: #"\b(3[5-9]|4[0-8])[.,]([05])\b"#) {
            return "\(dec[1]).\(dec[2])"
        }

        if matches(upper, pattern: #"\b(XXXL|XXL|XL|L|M|S|XS|XXS)\b"#) {
            return upper
        }

        if matches(trimmed, pattern: #"^(3[5-9]|4[0-8])$"#) {
            return trimmed
        }

        return nil
    }

    static func extractFromTitle(_ title: String) -> String? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }

        if matches(t, pattern: #"(?i)\b(one\s*size|taille\s*unique|unique|tu|os)\b"#) {
            return "OS"
        }

        if let frac = firstMatch(in: t, pattern: #"\b(3[5-9]|4[0-8])\s+([12])\s*/\s*([23])\b"#) {
            return "\(frac[1]) \(frac[2])/\(frac[3])"
        }

        if let dec = firstMatch(in: t, pattern: #"\b(3[5-9]|4[0-8])[.,]([05])\b"#) {
            return "\(dec[1]).\(dec[2])"
        }

        if let tShoe = firstMatch(in: t, pattern: #"(?i)\bT\s*(3[5-9]|4[0-8])(?:[.,][05])?\b"#) {
            return tShoe[1]
        }

        if let paren = firstMatch(in: t, pattern: #"\(\s*(3[5-9]|4[0-8])\s+([12])\s*/\s*([23])\s*\)"#) {
            return "\(paren[1]) \(paren[2])/\(paren[3])"
        }

        if let numDot = firstMatch(in: t, pattern: #"(?i)\bnum\.?\s*(3[5-9]|4[0-8])(?:\s+[12]\s*/\s*[23]|[.,][05])?\b"#) {
            if let fracIn = firstMatch(
                in: t,
                pattern: #"(?i)\bnum\.?\s*(3[5-9]|4[0-8])\s+([12])\s*/\s*([23])\b"#
            ) {
                return "\(fracIn[1]) \(fracIn[2])/\(fracIn[3])"
            }
            if let decIn = firstMatch(
                in: t,
                pattern: #"(?i)\bnum\.?\s*(3[5-9]|4[0-8])[.,]([05])\b"#
            ) {
                return "\(decIn[1]).\(decIn[2])"
            }
            return numDot[1]
        }

        if let taille = firstMatch(in: t, pattern: #"(?i)\btaille\s*:?\s*(3[5-9]|4[0-8])(?:\s+[12]\s*/\s*[23])?\b"#) {
            if let fracIn = firstMatch(
                in: t,
                pattern: #"(?i)\btaille\s*(3[5-9]|4[0-8])\s+([12])\s*/\s*([23])\b"#
            ) {
                return "\(fracIn[1]) \(fracIn[2])/\(fracIn[3])"
            }
            return taille[1]
        }

        if let sizeKw = firstMatch(
            in: t,
            pattern: #"(?i)\b(?:size|pointure|eu|uk|us)\s*:?\s*(3[5-9]|4[0-8])(?:\s+[12]\s*/\s*[23]|[.,][05])?\b"#
        ) {
            if let fracIn = firstMatch(
                in: t,
                pattern: #"(?i)\b(?:size|pointure|eu|uk|us)\s*(3[5-9]|4[0-8])\s+([12])\s*/\s*([23])\b"#
            ) {
                return "\(fracIn[1]) \(fracIn[2])/\(fracIn[3])"
            }
            if let decIn = firstMatch(
                in: t,
                pattern: #"(?i)\b(?:size|pointure|eu|uk|us)\s*(3[5-9]|4[0-8])[.,]([05])\b"#
            ) {
                return "\(decIn[1]).\(decIn[2])"
            }
            return sizeKw[1]
        }

        if let femme = firstMatch(in: t, pattern: #"(?i)\b(3[5-9]|4[0-8])\s*(?:femme|homme|women|men)\b"#) {
            return femme[1]
        }

        if let femmeSuffix = firstMatch(
            in: t,
            pattern: #"(?i)\b(?:femme|homme|women|men)\s*(3[5-9]|4[0-8])\b"#
        ) {
            return femmeSuffix[1]
        }

        if let clothing = firstMatch(in: t, pattern: #"\b(XXXL|XXL|XL|L|M|S|XS|XXS)\b"#) {
            return clothing[1].uppercased()
        }

        if !titleLooksNoisy(t),
           let contextual = firstMatch(
               in: t,
               pattern: #"(?i)\b(?:taille|size|pointure)\s*(XXXL|XXL|XL|L|M|S|XS|XXS)\b"#
           ) {
            return contextual[1].uppercased()
        }

        return nil
    }

    // MARK: - Regex helpers

    private static func titleLooksNoisy(_ title: String) -> Bool {
        matches(title, pattern: #"(?i)\b(spezial|samba|gazelle|campus|forum|superstar|stan\s*smith|air\s*max|dunk|jordan|yeezy|550|2002|990|574|9060)\s*\d{2}\b"#)
            || matches(title, pattern: #"\b(19|20)\d{2}\b"#)
            || matches(title, pattern: #"\b\d+[.,]\d{2}\s*€"#)
    }

    private static func matches(_ text: String, pattern: String) -> Bool {
        firstMatch(in: text, pattern: pattern) != nil
    }

    private static func firstMatch(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        var groups: [String] = []
        for index in 0 ..< match.numberOfRanges {
            let nsRange = match.range(at: index)
            guard nsRange.location != NSNotFound,
                  let swiftRange = Range(nsRange, in: text) else {
                groups.append("")
                continue
            }
            groups.append(String(text[swiftRange]))
        }
        return groups
    }
}
