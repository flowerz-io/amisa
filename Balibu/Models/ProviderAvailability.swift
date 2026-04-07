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

/// Totaux backend par provider (différent des cartes déjà chargées).
struct ProviderCountsDTO: Codable, Hashable {
    var vinted: Int?
    var grailed: Int?
    var ebay: Int?
    var leboncoin: Int?
    var depop: Int?

    func count(for providerKey: String) -> Int? {
        switch MarketplaceSource.canonicalKey(from: providerKey) {
        case "vinted": return vinted
        case "grailed": return grailed
        case "ebay": return ebay
        case "leboncoin": return leboncoin
        case "depop": return depop
        default: return nil
        }
    }

    /// Fusionne en donnant la priorité aux nouvelles valeurs non-nil.
    func merged(with delta: ProviderCountsDTO?) -> ProviderCountsDTO {
        guard let delta else { return self }
        return ProviderCountsDTO(
            vinted: delta.vinted ?? vinted,
            grailed: delta.grailed ?? grailed,
            ebay: delta.ebay ?? ebay,
            leboncoin: delta.leboncoin ?? leboncoin,
            depop: delta.depop ?? depop
        )
    }

    var sum: Int {
        [vinted, grailed, ebay, leboncoin, depop].compactMap { $0 }.reduce(0, +)
    }
}
