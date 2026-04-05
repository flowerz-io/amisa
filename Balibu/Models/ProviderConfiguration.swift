//
//  ProviderConfiguration.swift
//  Balibu
//

import Foundation

enum ProviderID: String, CaseIterable, Codable, Hashable {
    case vinted
    case grailed
    case ebay
    case depop
    case leboncoin

    var backendKey: String { rawValue }

    var displayName: String {
        switch self {
        case .vinted: return "Vinted"
        case .grailed: return "Grailed"
        case .ebay: return "eBay"
        case .depop: return "Depop"
        case .leboncoin: return "Le Bon Coin"
        }
    }

    var logoSourceName: String { displayName }

    var defaultEnabled: Bool {
        switch self {
        case .leboncoin:
            // Anti-bot récurrent: désactivé par défaut.
            return false
        default:
            return true
        }
    }

    var userDefaultsKey: String {
        "balibu.providers.enabled.\(rawValue)"
    }
}

struct ProviderMetadata: Identifiable, Hashable {
    let id: ProviderID
    let displayName: String
    let logoSourceName: String
    let defaultEnabled: Bool
}

enum ProviderCatalog {
    static let all: [ProviderMetadata] = ProviderID.allCases.map { id in
        ProviderMetadata(
            id: id,
            displayName: id.displayName,
            logoSourceName: id.logoSourceName,
            defaultEnabled: id.defaultEnabled
        )
    }
}

