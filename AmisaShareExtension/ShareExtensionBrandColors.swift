//
//  ShareExtensionBrandColors.swift
//  Miroir des constantes `BrandColors` de l’app — l’extension ne peux pas importer le module Amisa.
//

import SwiftUI

enum ShareExtensionBrandColors {
    static let primaryRed = Color(red: 202 / 255, green: 33 / 255, blue: 33 / 255)
    static let secondaryOrange = Color(red: 232 / 255, green: 108 / 255, blue: 38 / 255)

    static var primaryGradientColors: [Color] {
        [primaryRed, secondaryOrange.opacity(0.94)]
    }
}
