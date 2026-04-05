//
//  ResultsFiltersBar.swift
//
//  Barre horizontale : UI seulement, sheets placeholder.
//

import SwiftUI

struct ResultsFiltersBar: View {
    let onSelectTab: (ResultsFilterTab) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingXS) {
                FilterChip(title: String(localized: "Filtrer"), systemImage: "line.3.horizontal.decrease.circle") {
                    onSelectTab(.marketplace)
                }
                FilterChip(title: String(localized: "Taille"), systemImage: "ruler") {
                    onSelectTab(.size)
                }
                FilterChip(title: String(localized: "Marque"), systemImage: "tag") {
                    onSelectTab(.brand)
                }
                FilterChip(title: String(localized: "État"), systemImage: "checkmark.seal") {
                    onSelectTab(.condition)
                }
                FilterChip(title: String(localized: "Couleur"), systemImage: "paintpalette") {
                    onSelectTab(.color)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
