//
//  ResultsView.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI

struct ResultsView: View {
    @StateObject private var viewModel: ResultsViewModel

    private let listingGridColumns = [
        GridItem(.flexible(), spacing: DesignTokens.spacingM),
        GridItem(.flexible(), spacing: DesignTokens.spacingM),
    ]

    init(session: SearchSession) {
        _viewModel = StateObject(wrappedValue: ResultsViewModel(session: session))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loaded(let session):
                resultsContent(session: session)

            case .error(let message):
                errorState(message: message)

            case .empty:
                emptyState()
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(uiColor: .secondarySystemGroupedBackground), for: .navigationBar)
    }

    @ViewBuilder
    private func resultsContent(session: SearchSession) -> some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingL) {
                if let image = session.sourceImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
                }

                if !session.generatedQueries.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                        Text("Search queries")
                            .font(DesignTokens.caption)
                            .foregroundStyle(Color.secondary)
                        ForEach(session.generatedQueries, id: \.self) { query in
                            Text(query)
                                .font(DesignTokens.body)
                                .foregroundStyle(Color.primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.spacingM)
                    .background(DesignTokens.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
                } else if let query = session.generatedQuery {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                        Text("Search query")
                            .font(DesignTokens.caption)
                            .foregroundStyle(Color.secondary)
                        Text(query)
                            .font(DesignTokens.body)
                            .foregroundStyle(Color.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.spacingM)
                    .background(DesignTokens.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
                }

                if let attrs = session.attributes {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                        Text("Detected attributes")
                            .font(DesignTokens.headline)
                            .foregroundStyle(Color.primary)

                        Text("Category: \(attrs.category ?? "—")")
                        Text("Subcategory: \(attrs.subcategory ?? "—")")
                        Text("Brand: \(attrs.probableBrand ?? "—")")
                        Text("Color: \(attrs.color ?? "—")")
                        Text("Material: \(attrs.material ?? "—")")
                        Text("Item: \(attrs.dominantItem ?? "—")")
                        Text("Keywords: \((attrs.styleKeywords ?? []).isEmpty ? "—" : (attrs.styleKeywords ?? []).joined(separator: ", "))")
                    }
                    .font(DesignTokens.body)
                    .foregroundStyle(Color.primary)
                    .padding(DesignTokens.spacingM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
                }

                VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
                    Text("\(session.listings.count) matches")
                        .font(DesignTokens.headline)
                        .foregroundStyle(Color.primary)

                    LazyVGrid(columns: listingGridColumns, spacing: DesignTokens.spacingM) {
                        ForEach(session.listings) { listing in
                            ListingCardView(listing: listing)
                        }
                    }
                }
            }
            .padding(DesignTokens.spacingM)
        }
        .background(DesignTokens.background)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: DesignTokens.spacingL) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.secondary)
            Text(message)
                .font(DesignTokens.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState() -> some View {
        VStack(spacing: DesignTokens.spacingL) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.secondary)
            Text("No results found")
                .font(DesignTokens.headline)
                .foregroundStyle(Color.primary)
            Text("Try a different image or search query.")
                .font(DesignTokens.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        ResultsView(session: .mock)
    }
}
