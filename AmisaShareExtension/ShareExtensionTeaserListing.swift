//
//  ShareExtensionTeaserListing.swift
//  BalibuShareExtension
//
//  Cartes d’aperçu dans l’extension — données extraites du GET session.
//

import Foundation

struct ShareExtensionTeaserListing: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let price: Double
    let currency: String?
    let imageURL: URL?
    let thumbnailURL: URL?
    let source: String

    var formattedPrice: String {
        let amount = price
        let code = (currency ?? "").uppercased()
        if code == "EUR" {
            return String(format: "%.0f €", amount)
        }
        if code == "USD" {
            return String(format: "$%.0f", amount)
        }
        if code.isEmpty {
            return String(format: "%.0f", amount)
        }
        return String(format: "%.0f %@", amount, code)
    }

    var displaySource: String {
        MarketplaceSource.displayLabel(from: source)
    }

    init(
        id: String,
        title: String,
        price: Double,
        currency: String?,
        imageURL: URL?,
        thumbnailURL: URL?,
        source: String
    ) {
        self.id = id
        self.title = title
        self.price = price
        self.currency = currency
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.source = source
    }
}

// MARK: - Parsing GET /search-sessions/:id

enum ShareExtensionTeaserListingParser {
    /// Extrait les annonces depuis `response.listings` (corps Railway aligné sur `AnalyzeSearchResponse`).
    static func listings(from jsonData: Data) -> [ShareExtensionTeaserListing] {
        guard let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }
        let listingsArray: [[String: Any]] = {
            if let response = root["response"] as? [String: Any],
               let arr = response["listings"] as? [[String: Any]] {
                return arr
            }
            if let arr = root["listings"] as? [[String: Any]] {
                return arr
            }
            return []
        }()
        return listingsArray.compactMap { dict in
            guard let id = dict["id"] as? String else { return nil }
            let title = dict["title"] as? String ?? ""
            let price = dict["price"] as? Double ?? 0
            let currency = dict["currency"] as? String
            let imageUrlString = dict["imageUrl"] as? String ?? dict["imageURL"] as? String
            let thumbString = dict["thumbnailUrl"] as? String ?? dict["thumbnailURL"] as? String
            let source = dict["source"] as? String ?? "?"
            return ShareExtensionTeaserListing(
                id: id,
                title: title,
                price: price,
                currency: currency,
                imageURL: imageUrlString.flatMap { URL(string: $0) },
                thumbnailURL: (thumbString ?? imageUrlString).flatMap { URL(string: $0) },
                source: source
            )
        }
    }
}

// MARK: - Source label (copie minimale du domaine app)

private enum MarketplaceSource {
    static func displayLabel(from raw: String) -> String {
        let key = canonicalKey(from: raw)
        if key == "vinted" || raw.isEmpty { return "Vinted" }
        return raw
    }

    static func canonicalKey(from source: String) -> String {
        source.lowercased().replacingOccurrences(of: " ", with: "")
    }
}
