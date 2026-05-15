//
//  ResultsSkeletonViews.swift
//  Balibu
//
//  Skeletons + shimmer pour la grille résultats (continuité extension → app).
//

import SwiftUI

// MARK: - Shimmer

private struct SkeletonShimmerOverlay: View {
    @State private var slide: CGFloat = -1
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let bandW = w * 0.55
            LinearGradient(
                colors: [
                    .clear,
                    colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.55),
                    .clear,
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: bandW)
            .offset(x: slide * (w + bandW))
            .onAppear {
                withAnimation(.linear(duration: 1.28).repeatForever(autoreverses: false)) {
                    slide = 1
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Carte (dimensions alignées sur MarketplaceVisualCard)

struct ResultsListingSkeletonCard: View {
    private enum Layout {
        static let cardHeight: CGFloat = 236
        static let cornerRadius: CGFloat = 19
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemFill))

            SkeletonShimmerOverlay()
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
                .blendMode(.overlay)

            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(uiColor: .quaternarySystemFill))
                    .frame(width: 100, height: 11)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(uiColor: .quaternarySystemFill))
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                HStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .quaternarySystemFill))
                        .frame(width: 44, height: 26)
                    Spacer()
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(uiColor: .quaternarySystemFill))
                        .frame(width: 56, height: 18)
                }
            }
            .padding(12)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .quaternarySystemFill))
                .frame(width: 58, height: 22)
                .padding(12)
        }
        .frame(height: Layout.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct ResultsListingSkeletonGrid: View {
    let columns: [GridItem]
    let rowSpacing: CGFloat

    private let placeholderCount = 10

    init(
        columns: [GridItem],
        rowSpacing: CGFloat = 14
    ) {
        self.columns = columns
        self.rowSpacing = rowSpacing
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: rowSpacing) {
            ForEach(0..<placeholderCount, id: \.self) { index in
                ResultsListingSkeletonCard()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .animation(
                        .easeOut(duration: 0.32).delay(Double(index) * 0.035),
                        value: placeholderCount
                    )
            }
        }
        .accessibilityLabel(Text(String(localized: "Chargement des annonces")))
    }
}
