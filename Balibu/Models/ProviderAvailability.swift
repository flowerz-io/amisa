//
//  ProviderAvailability.swift
//  Balibu
//
//  Disponibilité des providers (aligné backend : ok / no_results / blocked_by_challenge / provider_error).
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

/// Carte `providerAvailability` de `/analyze-search` et `/search-more`.
struct ProviderAvailabilityMapDTO: Codable, Hashable {
    var vinted: ProviderAvailabilityDTO?
    var grailed: ProviderAvailabilityDTO?
    var ebay: ProviderAvailabilityDTO?
    var leboncoin: ProviderAvailabilityDTO?
    var depop: ProviderAvailabilityDTO?

    /// Fusionne en donnant la priorité au delta (réponse pagination).
    func merged(with delta: ProviderAvailabilityMapDTO?) -> ProviderAvailabilityMapDTO {
        guard let delta else { return self }
        return ProviderAvailabilityMapDTO(
            vinted: delta.vinted ?? vinted,
            grailed: delta.grailed ?? grailed,
            ebay: delta.ebay ?? ebay,
            leboncoin: delta.leboncoin ?? leboncoin,
            depop: delta.depop ?? depop
        )
    }
}
