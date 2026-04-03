//
//  DesignTokens.swift
//  Balibu
//
//  Created for Balibu MVP. Couleurs sémantiques UIKit (clair / sombre).
//

import SwiftUI

enum DesignTokens {
    // MARK: - Colors (sémantiques — clair / sombre système)
    static let backgroundColor = Color(uiColor: .systemGroupedBackground)
    static let backgroundPrimary = Color(uiColor: .systemGroupedBackground)
    static let backgroundSecondary = Color(uiColor: .secondarySystemGroupedBackground)
    static let backgroundCard = Color(uiColor: .secondarySystemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    /// Fond carte listing (grille Results)
    static let cardFill = Color(uiColor: .secondarySystemGroupedBackground)
    /// Contour discret carte
    static let cardStroke = Color(uiColor: .separator)
    /// Placeholder image async
    static let imagePlaceholderFill = Color(uiColor: .tertiarySystemFill)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    static let accent = Color.accentColor
    static let accentMuted = Color(uiColor: .tertiarySystemFill)
    static let divider = Color(uiColor: .separator)
    static let borderColor = Color(uiColor: .separator)
    static let error = Color(red: 0.9, green: 0.3, blue: 0.3)
    static let errorColor = Color(red: 0.9, green: 0.3, blue: 0.3)
    static let success = Color(uiColor: .systemGreen)

    enum Colors {
        static let background = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let surfaceSecondary = Color(uiColor: .tertiarySystemGroupedBackground)
        static let text = Color(uiColor: .label)
        static let textSecondary = Color(uiColor: .secondaryLabel)
    }

    // MARK: - Typography
    static let titleFont = Font.system(size: 28, weight: .semibold, design: .default)
    static let headlineFont = Font.system(size: 17, weight: .medium, design: .default)
    static let bodyFont = Font.system(size: 15, weight: .regular, design: .default)
    static let captionFont = Font.system(size: 13, weight: .regular, design: .default)
    static let fontLargeTitle = Font.system(size: 28, weight: .semibold, design: .default)
    static let fontTitle = Font.system(size: 20, weight: .semibold, design: .default)
    static let fontHeadline = Font.system(size: 17, weight: .medium, design: .default)
    static let fontBody = Font.system(size: 15, weight: .regular, design: .default)
    static let fontCaption = Font.system(size: 13, weight: .regular, design: .default)

    enum Typography {
        static let headline = Font.system(size: 17, weight: .medium, design: .default)
        static let body = Font.system(size: 15, weight: .regular, design: .default)
        static let caption = Font.system(size: 13, weight: .regular, design: .default)
    }

    // MARK: - Spacing
    static let spacingXXS: CGFloat = 4
    static let spacingXS: CGFloat = 8
    static let spacingS: CGFloat = 12
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    // MARK: - Corner Radius
    static let cornerRadiusS: CGFloat = 8
    static let cornerRadiusM: CGFloat = 12
    static let cornerRadiusL: CGFloat = 16
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 16
    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 12

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
    }

    static let cardPadding: CGFloat = spacingM
    static let cardCornerRadius: CGFloat = radiusM

    // Aliases pour ResultsView / SearchHistoryView
    static let text = textPrimary
    static let body = bodyFont
    static let caption = captionFont
    static let headline = headlineFont
    static let surface = Colors.surface
    static let surfaceSecondary = Colors.surfaceSecondary
    static let background = backgroundColor
}
