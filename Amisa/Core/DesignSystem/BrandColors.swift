//
//  BrandColors.swift
//  Amisa — couleurs de marque (module Amisa).
//
//  Palette premium mode / luxe — rouge profond + orange chaud.
//  Préférer les fonds système (label, groupedBackground) pour texte et surfaces.
//

import SwiftUI

enum BrandColors {
    // MARK: - Noyau marque (hex demandés)

    /// Rouge principal — #CA2121
    static let primaryRed = Color(red: 202 / 255, green: 33 / 255, blue: 33 / 255)

    /// Orange secondaire — #E86C26
    static let secondaryOrange = Color(red: 232 / 255, green: 108 / 255, blue: 38 / 255)

    // MARK: - Alias (compatibilité codebase)

    /// Alias histor vers le rouge principal.
    static let primary = primaryRed
    /// Alias histor vers l’orange secondaire.
    static let secondary = secondaryOrange

    // MARK: - États & variantes (lisibilité, CTA, disabled)

    /// Rouge appuyé / survol — légèrement plus sombre, moins saturé en UI.
    static let primaryPressed = Color(red: 163 / 255, green: 27 / 255, blue: 27 / 255)

    /// Rouge atténué (badges, fonds discrets, mode sombre).
    static let primarySubtle = primaryRed.opacity(0.14)

    /// Orange atténué (halos, sous-couches chaudes).
    static let secondarySubtle = secondaryOrange.opacity(0.18)

    /// CTA désactivé — même teinte, opacité accessible sans bascule sur du gris froid.
    static let primaryDisabled = primaryRed.opacity(0.38)

    // MARK: - Gradients marque

    /// Gradient principal premium : rouge → orange (légèrement arrondi en fin pour éviter saturation).
    static var primaryGradientColors: [Color] {
        [primaryRed, secondaryOrange.opacity(0.94)]
    }

    /// LinearGradient standard (CTA, barres, pastilles).
    static var primaryLinearGradient: LinearGradient {
        LinearGradient(
            colors: primaryGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Variant horizontal (piste de progression, pills).
    static var primaryLinearGradientHorizontal: LinearGradient {
        LinearGradient(
            colors: primaryGradientColors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Fond onboarding / paywall : dégradé sombre chaud (charbon + bordeaux), sans bleu.
    static var editorialDarkBackground: [Color] {
        [
            Color(red: 0.09, green: 0.06, blue: 0.055),
            Color(red: 0.14, green: 0.08, blue: 0.065),
        ]
    }
}
