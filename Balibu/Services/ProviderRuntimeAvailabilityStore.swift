//
//  ProviderRuntimeAvailabilityStore.swift
//  Balibu
//
//  Dernière disponibilité connue (ex. eBay bloqué) pour Réglages et filtres.
//

import Foundation
import Combine

@MainActor
final class ProviderRuntimeAvailabilityStore: ObservableObject {
    static let shared = ProviderRuntimeAvailabilityStore()

    @Published private(set) var ebay: ProviderAvailabilityDTO?

    private init() {}

    func merge(from map: ProviderAvailabilityMapDTO?) {
        guard let map else { return }
        if let e = map.ebay {
            ebay = e
        }
    }

    func clearEbay() {
        ebay = nil
    }
}
