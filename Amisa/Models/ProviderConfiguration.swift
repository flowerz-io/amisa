//
//  ProviderConfiguration.swift
//  Balibu
//

import Foundation

enum ProviderID: String, CaseIterable, Codable, Hashable {
    case vinted

    var backendKey: String { rawValue }

    var displayName: String {
        switch self {
        case .vinted: return "Vinted"
        }
    }

    var logoSourceName: String { displayName }

    var defaultEnabled: Bool { true }

    var userDefaultsKey: String {
        "amisa.providers.enabled.\(rawValue)"
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
