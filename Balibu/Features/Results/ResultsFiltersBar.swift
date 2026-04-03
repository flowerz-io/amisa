//
//  ResultsFiltersBar.swift
//
//  Barre horizontale : UI seulement, sheets placeholder.
//

import SwiftUI

struct ResultsFiltersBar: View {
    @Binding var showFilterSheet: Bool
    @Binding var showSizeSheet: Bool
    @Binding var showBrandSheet: Bool
    @Binding var showConditionSheet: Bool
    @Binding var showColorSheet: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingXS) {
                FilterChip(title: String(localized: "Filtrer"), systemImage: "line.3.horizontal.decrease.circle") {
                    showFilterSheet = true
                }
                FilterChip(title: String(localized: "Taille"), systemImage: "ruler") {
                    showSizeSheet = true
                }
                FilterChip(title: String(localized: "Marque"), systemImage: "tag") {
                    showBrandSheet = true
                }
                FilterChip(title: String(localized: "État"), systemImage: "checkmark.seal") {
                    showConditionSheet = true
                }
                FilterChip(title: String(localized: "Couleur"), systemImage: "paintpalette") {
                    showColorSheet = true
                }
            }
            .padding(.vertical, 2)
        }
    }
}
