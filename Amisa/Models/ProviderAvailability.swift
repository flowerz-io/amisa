//
//  ProviderAvailability.swift
//  Balibu
//

import Foundation

enum ProviderAvailabilityStatus: String, Codable, Hashable {
    case ok
    case no_results
    case blocked_by_challenge
    case provider_error
}

struct ProviderAvailabilityDTO: Codable, Hashable {
    let status: ProviderAvailabilityStatus
    let reason: String?
}

struct ProviderAvailabilityMapDTO: Codable, Hashable {
    var vinted: ProviderAvailabilityDTO?

    func merged(with delta: ProviderAvailabilityMapDTO?) -> ProviderAvailabilityMapDTO {
        guard let delta else { return self }
        return ProviderAvailabilityMapDTO(vinted: delta.vinted ?? vinted)
    }
}

struct ProviderCountsDTO: Codable, Hashable {
    var vinted: Int?

    func count(for providerKey: String) -> Int? {
        MarketplaceSource.canonicalKey(from: providerKey) == "vinted" ? vinted : nil
    }

    func merged(with delta: ProviderCountsDTO?) -> ProviderCountsDTO {
        guard let delta else { return self }
        return ProviderCountsDTO(vinted: delta.vinted ?? vinted)
    }

    var sum: Int {
        vinted ?? 0
    }
}
