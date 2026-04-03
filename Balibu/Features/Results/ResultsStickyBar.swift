//
//  ResultsStickyBar.swift
//  Balibu
//
//  Barre collante : miniature + filtres (structure prête).
//

import SwiftUI
import UIKit

struct ResultsStickyBar: View {
    let thumbnail: UIImage?
    @Binding var showSizeSheet: Bool
    @Binding var showPriceSheet: Bool
    @Binding var showConditionSheet: Bool
    let onInfoTap: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.spacingS) {
            Group {
                if let ui = thumbnail {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: DesignTokens.radiusS, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(Color.secondary)
                        }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS, style: .continuous))

            ResultsFiltersBar(
                showSizeSheet: $showSizeSheet,
                showPriceSheet: $showPriceSheet,
                showConditionSheet: $showConditionSheet,
                onInfoTap: onInfoTap
            )
        }
        .padding(.horizontal, DesignTokens.spacingM)
        .padding(.vertical, DesignTokens.spacingXS)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
    }
}
