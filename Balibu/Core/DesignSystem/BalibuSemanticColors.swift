//
//  BalibuSemanticColors.swift
//  Balibu
//
//  Couleurs adaptatives centralisées (light/dark + AccentColor).
//

import SwiftUI

enum BalibuSemanticColors {
    static func tabItemForeground(isSelected: Bool, colorScheme: ColorScheme) -> Color {
        if isSelected { return Color.accentColor }
        return colorScheme == .dark ? Color.white.opacity(0.9) : Color.black
    }

    static func tabItemSecondaryForeground(isSelected: Bool, colorScheme: ColorScheme) -> Color {
        if isSelected { return Color.accentColor }
        return colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.7)
    }

    /// Icône scan : même logique que les onglets non sélectionnés (pas d’AccentColor).
    static func scanButtonIconForeground(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color.black
    }

    /// Piste de barre de progression (s’adapte au mode clair/sombre).
    static func progressTrackFill() -> Color {
        Color(uiColor: .tertiarySystemFill)
    }
}
