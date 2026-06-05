//
//  AmisaChrome.swift
//  Amisa
//
//  Constantes visuelles partagées (cards, empty states, filtres).
//

import SwiftUI

enum AmisaChrome {
    // MARK: - Product cards (Results / Home)

    static let productCardHeight: CGFloat = 236
    static let productCardRadius: CGFloat = 20
    static let productCardShadow = Color.black.opacity(0.09)
    static let productCardShadowRadius: CGFloat = 10
    static let productCardShadowY: CGFloat = 4

    // MARK: - Filters

    static let filterPillHorizontalPadding: CGFloat = 14
    static let filterPillVerticalPadding: CGFloat = 7
    static let filterBarSpacing: CGFloat = 8

    // MARK: - Hero image (Results)

    static let analyzedImageShadow = Color.black.opacity(0.14)
    static let analyzedImageShadowRadius: CGFloat = 14
    static let analyzedImageBorderOpacity: CGFloat = 0.12

    // MARK: - Empty states

    static let emptyStateRadius: CGFloat = 20
    static let emptyStatePadding: CGFloat = 28
    static let emptyStateIconSize: CGFloat = 48

    // MARK: - Profile / analyses grid

    static let analysisThumbMinSize: CGFloat = 88
    static let analysisThumbRadius: CGFloat = 12
    static let analysisGridSpacing: CGFloat = 8

    // MARK: - Settings sections

    static let settingsSectionRadius: CGFloat = 18
    static let settingsSectionSpacing: CGFloat = 32
    static let settingsRowHeight: CGFloat = 52

    // MARK: - Review / crop

    static let reviewCropContainerRadius: CGFloat = 20
}
