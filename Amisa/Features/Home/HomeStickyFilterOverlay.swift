//
//  HomeStickyFilterOverlay.swift
//  Overlay absolu : filtres sticky sous la status bar (+10 pt), hors flux du ScrollView.
//

import SwiftUI

struct HomeStickyFilterOverlay: View {
    /// `safeAreaInsets.top` (bas de la status bar / encoche).
    let safeTop: CGFloat
    let onSelectTab: (ResultsFilterTab) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var gradientChrome: Color {
        colorScheme == .dark ? .black : Color.homeLightChrome
    }

    var body: some View {
        VStack(spacing: 0) {
            ResultsFiltersBar(onSelectTab: onSelectTab)
                .padding(.top, safeTop + 10)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(alignment: .top) {
            LinearGradient(
                colors: [
                    gradientChrome.opacity(0.95),
                    gradientChrome.opacity(0.55),
                    gradientChrome.opacity(0.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: safeTop + 80)
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(true)
        .compositingGroup()
        .zIndex(9999)
    }
}
