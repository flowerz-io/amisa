//
//  ProviderSettingsStore.swift
//  Balibu
//

import Foundation
import Combine

final class ProviderSettingsStore: ObservableObject {
    static let shared = ProviderSettingsStore()

    @Published private(set) var states: [ProviderID: Bool]

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        var initial: [ProviderID: Bool] = [:]
        for provider in ProviderID.allCases {
            initial[provider] = userDefaults.object(forKey: provider.userDefaultsKey) as? Bool ?? provider.defaultEnabled
        }
        self.states = initial
    }

    func isEnabled(_ provider: ProviderID) -> Bool {
        states[provider] ?? provider.defaultEnabled
    }

    func setEnabled(_ enabled: Bool, for provider: ProviderID) {
        states[provider] = enabled
        userDefaults.set(enabled, forKey: provider.userDefaultsKey)
    }

    var enabledProviderIDs: [ProviderID] {
        ProviderID.allCases.filter { isEnabled($0) }
    }

    var enabledProviderBackendKeys: [String] {
        enabledProviderIDs.map(\.backendKey)
    }

    /// Toujours Vinted — seul provider supporté par le backend.
    static func enabledProviderBackendKeysSnapshot(userDefaults: UserDefaults = .standard) -> [String] {
        _ = userDefaults
        return ["vinted"]
    }
}
