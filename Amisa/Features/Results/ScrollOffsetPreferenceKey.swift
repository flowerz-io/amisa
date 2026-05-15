//
//  ScrollOffsetPreferenceKey.swift
//  Balibu
//
//  PreferenceKeys pour le suivi du scroll dans les résultats.
//

import SwiftUI

/// Position verticale du haut du hero (frame.minY) dans l'espace `resultsScroll`.
/// Conservé pour rétro-compatibilité ; préférer ScrollOffsetPreferenceKey.
struct HeroVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// minY de l'ancre du scrollview dans l'espace `resultsScroll`.
/// Valeur négative = l'utilisateur a scrollé vers le bas.
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Offset dédié à l'animation du header flottant de ResultsView.
struct ResultsScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Position Y globale (écran) du haut du bloc hero image analysée.
struct AnalyzedHeroMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

/// Position Y globale (espace écran) de l'ancre de la barre de filtres.
/// Sert à déclencher la barre sticky quand la barre originale sort du champ de vue.
struct FilterBarMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

extension View {
    /// Ancre la préférence `AnalyzedHeroMinYPreferenceKey` avec le `minY` global du bloc hero image.
    func analyzedHeroGlobalMinYAnchor() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: AnalyzedHeroMinYPreferenceKey.self,
                    value: proxy.frame(in: .global).minY
                )
            }
        )
    }

    /// Ancre la préférence `FilterBarMinYPreferenceKey` avec le `minY` global de cette vue.
    func filterBarGlobalMinYAnchor() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: FilterBarMinYPreferenceKey.self,
                    value: proxy.frame(in: .global).minY
                )
            }
        )
    }
}
