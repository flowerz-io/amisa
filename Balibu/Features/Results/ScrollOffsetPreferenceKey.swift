//
//  ScrollOffsetPreferenceKey.swift
//  Balibu
//
//  Mesure la position du hero dans le ScrollView (coordinateSpace nommé).
//

import SwiftUI

/// Position verticale du haut du hero (frame.minY) dans l’espace `resultsScroll`.
struct HeroVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
