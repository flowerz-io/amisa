//
//  ProviderRuntimeAvailabilityStore.swift
//  Balibu
//

import Foundation
import Combine

@MainActor
final class ProviderRuntimeAvailabilityStore: ObservableObject {
    static let shared = ProviderRuntimeAvailabilityStore()

    private init() {}

    func merge(from map: ProviderAvailabilityMapDTO?) {
        _ = map
    }
}
