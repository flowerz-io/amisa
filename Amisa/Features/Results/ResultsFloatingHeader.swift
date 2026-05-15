//
//  ResultsFloatingHeader.swift
//

import SwiftUI
import UIKit

/// Contenu central du header : image analysée (compact) ou requête recherche manuelle.
enum ResultsHeaderContent {
    case analyzedImage(UIImage?)
    case manualQuery(String)
}

/// Carte requête — recherche manuelle (bandeau central entre réservations overlay boutons).
struct ManualSearchQueryCard: View {
    let query: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(query)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.85)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 280, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Requête compacte — recherche manuelle quand filtres sticky / header replié.
struct CompactManualQueryPill: View {
    let query: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))

            Text(query)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 180, height: 48, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Pills centrale : image analysée (mode compact header).
struct CompactAnalyzedImagePill: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                }

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 42)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(width: 74, height: 50)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Dégradé + pilule centrale + barre de filtres sticky. Les boutons retour/favori sont dans `ResultsHeaderButtonsOverlay`.
struct ResultsFloatingHeader: View {
    /// Aligné sur `ResultsHeaderButtonsOverlay` : padding horizontal 28 + diamètre bouton 62.
    private let sideGutterWidth: CGFloat = 28 + 62
    private let topButtonPadding: CGFloat = 10
    private let overlayButtonSize: CGFloat = 62
    private let gapBelowButtonRow: CGFloat = 12

    let safeTop: CGFloat
    let headerContent: ResultsHeaderContent
    /// Mode image : `true` quand le hero image a défilé sous le header. Mode manuel : `true` quand les filtres sont sticky.
    let showCompactCenter: Bool
    let shouldShowFilters: Bool
    let onPreviewTap: (() -> Void)?
    let onSelectFilterTab: (ResultsFilterTab) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var chromeBackground: Color {
        DesignTokens.background
    }

    /// Position verticale de la barre de filtres (sticky), sous la rangée des boutons overlay.
    private var filtersTopInset: CGFloat {
        safeTop + topButtonPadding + overlayButtonSize + gapBelowButtonRow
    }

    private var headerGradientHeight: CGFloat {
        shouldShowFilters ? filtersTopInset + 56 : safeTop + topButtonPadding + overlayButtonSize + 24
    }

    private var headerGradient: LinearGradient {
        switch colorScheme {
        case .dark:
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.95),
                    Color.black.opacity(0.78),
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            return LinearGradient(
                colors: [
                    chromeBackground.opacity(0.98),
                    chromeBackground.opacity(0.82),
                    chromeBackground.opacity(0.45),
                    chromeBackground.opacity(0.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            headerGradient
                .frame(height: headerGradientHeight)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .zIndex(0)

            VStack(alignment: .center, spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    Color.clear
                        .frame(width: sideGutterWidth)

                    headerCenterChrome
                        .frame(maxWidth: .infinity)

                    Color.clear
                        .frame(width: sideGutterWidth)
                }
                .frame(height: overlayButtonSize)
                .padding(.top, safeTop + topButtonPadding)

                if shouldShowFilters {
                    ResultsFiltersBar(onSelectTab: onSelectFilterTab)
                        .padding(.top, gapBelowButtonRow)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(true)
        .animation(.easeInOut(duration: 0.2), value: showCompactCenter)
        .animation(.easeInOut(duration: 0.2), value: shouldShowFilters)
    }

    @ViewBuilder
    private var headerCenterChrome: some View {
        switch headerContent {
        case .analyzedImage(let image):
            if showCompactCenter {
                HStack {
                    Spacer(minLength: 0)
                    CompactAnalyzedImagePill(image: image)
                        .transition(.scale.combined(with: .opacity))
                        .onTapGesture { onPreviewTap?() }
                        .accessibilityLabel(String(localized: "Agrandir l’image"))
                        .accessibilityAddTraits(.isButton)
                    Spacer(minLength: 0)
                }
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }

        case .manualQuery(let query):
            HStack {
                Spacer(minLength: 0)
                Group {
                    if showCompactCenter {
                        CompactManualQueryPill(query: query)
                    } else {
                        ManualSearchQueryCard(query: query)
                    }
                }
                .transition(.scale.combined(with: .opacity))
                Spacer(minLength: 0)
            }
        }
    }
}
