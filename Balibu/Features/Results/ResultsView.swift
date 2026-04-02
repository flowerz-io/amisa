//
//  ResultsView.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI

struct ResultsView: View {
    @StateObject private var viewModel: ResultsViewModel
    
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
        .toolbarBackground(DesignTokens.surface, for: .navigationBar)
    }
    
    @ViewBuilder
    private func resultsContent(session: SearchSession) -> some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingL) {
                // Original image
                if let image = session.sourceImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM))
                }
                
                // Generated queries
                if !session.generatedQueries.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                        Text("Search queries")
                            .font(DesignTokens.caption)
                            .foregroundColor(DesignTokens.textSecondary)
                        ForEach(session.generatedQueries, id: \.self) { query in
                            Text(query)
                                .font(DesignTokens.body)
                                .foregroundColor(DesignTokens.text)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.spacingM)
                    .background(DesignTokens.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM))
                } else if let query = session.generatedQuery {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                        Text("Search query")
                            .font(DesignTokens.caption)
                            .foregroundColor(DesignTokens.textSecondary)
                        Text(query)
                            .font(DesignTokens.body)
                            .foregroundColor(DesignTokens.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.spacingM)
                    .background(DesignTokens.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM))
                }
                
                // Vision result (attributes) if available
                if let attrs = session.attributes {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detected attributes")
                            .font(.headline)

                        Text("Category: \(attrs.category ?? "-")")
                        Text("Subcategory: \(attrs.subcategory ?? "-")")
                        Text("Brand: \(attrs.probableBrand ?? "-")")
                        Text("Color: \(attrs.color ?? "-")")
                        Text("Material: \(attrs.material ?? "-")")
                        Text("Item: \(attrs.dominantItem ?? "-")")
                        Text("Keywords: \((attrs.styleKeywords ?? []).isEmpty ? "-" : (attrs.styleKeywords ?? []).joined(separator: ", "))")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM))
                }
                
                // Listings
                VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
                    Text("\(session.listings.count) matches")
                        .font(DesignTokens.headline)
                        .foregroundColor(DesignTokens.text)
                    
                    LazyVStack(spacing: DesignTokens.spacingM) {
                        ForEach(session.listings) { listing in
                            ListingCard(listing: listing)
                        }
                    }
                }
            }
            .padding(DesignTokens.spacingM)
        }
        .background(DesignTokens.background)
    }
    
    private func attributeTags(_ attributes: [String]) -> some View {
        FlowLayout(spacing: DesignTokens.spacingXS) {
            ForEach(attributes, id: \.self) { attr in
                Text(attr)
                    .font(DesignTokens.caption)
                    .foregroundColor(DesignTokens.textSecondary)
                    .padding(.horizontal, DesignTokens.spacingS)
                    .padding(.vertical, DesignTokens.spacingXS)
                    .background(DesignTokens.surfaceSecondary)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func errorState(message: String) -> some View {
        VStack(spacing: DesignTokens.spacingL) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.textSecondary)
            Text(message)
                .font(DesignTokens.body)
                .foregroundColor(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func emptyState() -> some View {
        VStack(spacing: DesignTokens.spacingL) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.textSecondary)
            Text("No results found")
                .font(DesignTokens.headline)
                .foregroundColor(DesignTokens.text)
            Text("Try a different image or search query.")
                .font(DesignTokens.body)
                .foregroundColor(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Listing Card

private struct ListingCard: View {
    let listing: MarketplaceListing
    
    var body: some View {
        Button {
            listing.listingURL.map { UIApplication.shared.open($0) }
        } label: {
            HStack(spacing: DesignTokens.spacingM) {
                AsyncImage(url: listing.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(DesignTokens.surfaceSecondary)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundColor(DesignTokens.textSecondary)
                            }
                    case .empty:
                        Rectangle()
                            .fill(DesignTokens.surfaceSecondary)
                            .overlay { ProgressView() }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 80, height: 80)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
                
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text(listing.title)
                        .font(DesignTokens.body)
                        .foregroundColor(DesignTokens.text)
                        .lineLimit(2)
                    Text(listing.formattedPrice)
                        .font(DesignTokens.headline)
                        .foregroundColor(DesignTokens.text)
                    HStack(spacing: DesignTokens.spacingS) {
                        Text(listing.source)
                        if let size = listing.size, !size.isEmpty {
                            Text("•")
                            Text("Size \(size)")
                        }
                        if let condition = listing.condition, !condition.isEmpty {
                            Text("•")
                            Text(condition)
                        }
                    }
                    .font(DesignTokens.caption)
                    .foregroundColor(DesignTokens.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 4) {
                    Text("Open listing")
                        .font(DesignTokens.captionFont)
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignTokens.textSecondary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.textSecondary)
            }
            .padding(DesignTokens.spacingM)
            .background(DesignTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout (simple tags)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        let totalHeight = y + rowHeight
        let totalWidth = subviews.isEmpty ? 0 : (frames.map { $0.maxX }.max() ?? 0)
        return (CGSize(width: totalWidth, height: totalHeight), frames)
    }
}

#Preview {
    NavigationStack {
        ResultsView(session: .mock)
    }
}
