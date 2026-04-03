//
//  ResultsFiltersBar.swift
//  Balibu
//
//  Filtres placeholder + accès détails. Logique métier à brancher plus tard.
//

import SwiftUI

struct ResultsFiltersBar: View {
    @Binding var showSizeSheet: Bool
    @Binding var showPriceSheet: Bool
    @Binding var showConditionSheet: Bool
    let onInfoTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingXS) {
                FilterChip(title: String(localized: "Taille"), systemImage: "ruler") {
                    showSizeSheet = true
                }
                FilterChip(title: String(localized: "Prix"), systemImage: "eurosign.circle") {
                    showPriceSheet = true
                }
                FilterChip(title: String(localized: "État"), systemImage: "tag") {
                    showConditionSheet = true
                }
                FilterChip(title: String(localized: "Infos"), systemImage: "info.circle") {
                    onInfoTap()
                }
            }
            .padding(.vertical, 2)
        }
    }
}
