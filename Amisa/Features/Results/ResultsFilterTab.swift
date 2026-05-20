//
//  ResultsFilterTab.swift
//  Balibu
//

import Foundation

enum ResultsFilterTab: String, CaseIterable, Identifiable {
    case marketplace
    case size
    case brand
    case condition
    case color

    var id: String { rawValue }

    var title: String {
        switch self {
        case .marketplace: return String(localized: "Vinted")
        case .size: return String(localized: "Taille")
        case .brand: return String(localized: "Marque")
        case .condition: return String(localized: "État")
        case .color: return String(localized: "Couleur")
        }
    }
}

