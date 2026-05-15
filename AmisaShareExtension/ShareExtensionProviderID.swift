//
//  ShareExtensionProviderID.swift
//  BalibuShareExtension
//
//  Aligné sur `ProviderID` / `ProviderSettingsStore` côté app (mêmes clés UserDefaults).
//

import Foundation

enum ShareExtensionProviderID: String, CaseIterable, Hashable {
    case vinted, grailed, ebay, depop, leboncoin

    var defaultsKey: String { "amisa.providers.enabled.\(rawValue)" }

    var displayName: String {
        switch self {
        case .vinted: return "Vinted"
        case .grailed: return "Grailed"
        case .ebay: return "eBay"
        case .depop: return "Depop"
        case .leboncoin: return "Le Bon Coin"
        }
    }

    var assetName: String {
        switch self {
        case .leboncoin: return "provider_leboncoin"
        default: return "provider_\(rawValue)"
        }
    }

    var defaultEnabled: Bool {
        switch self {
        case .leboncoin: return false
        default: return true
        }
    }

    var isEnabledInSettings: Bool {
        if UserDefaults.standard.object(forKey: defaultsKey) == nil {
            return defaultEnabled
        }
        return UserDefaults.standard.bool(forKey: defaultsKey)
    }

    /// Clés attendues par le backend (`enabledProviders`).
    static func enabledBackendKeys() -> [String] {
        allCases.filter(\.isEnabledInSettings).map(\.rawValue)
    }
}
