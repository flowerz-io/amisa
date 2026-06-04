//
//  AmisaAppGroup.swift
//  Amisa
//
//  Identifiant App Group — doit correspondre exactement aux entitlements (app + extension).
//

import Foundation

enum AmisaAppGroup {
    /// Entitlements : `Amisa.entitlements` + `AmisaShareExtension.entitlements`
    static let identifier = "group.io.flowerz.amisa"

    /// Ancien identifiant (rebrand Balibu) — migration uniquement.
    static let legacyIdentifier = "group.flowerz.io.Amisa"
}
