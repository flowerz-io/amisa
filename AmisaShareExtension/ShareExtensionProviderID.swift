//
//  ShareExtensionProviderID.swift
//  AmisaShareExtension
//

import Foundation

enum ShareExtensionProviderID: String, CaseIterable, Hashable {
    case vinted

    var defaultsKey: String { "amisa.providers.enabled.\(rawValue)" }

    var displayName: String { "Vinted" }

    var assetName: String { "provider_vinted" }

    var defaultEnabled: Bool { true }

    var isEnabledInSettings: Bool {
        if UserDefaults.standard.object(forKey: defaultsKey) == nil {
            return defaultEnabled
        }
        return UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func enabledBackendKeys() -> [String] {
        ["vinted"]
    }
}
