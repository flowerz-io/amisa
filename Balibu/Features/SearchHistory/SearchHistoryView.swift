//
//  SearchHistoryView.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI
import Combine

struct SearchHistoryView: View {
    @StateObject private var viewModel = SearchHistoryViewModel()
    
    var body: some View {
        Group {
            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DesignTokens.Colors.surface, for: .navigationBar)
        .onAppear { viewModel.load() }
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Text("No search history yet")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Colors.text)
            Text("Share an image to Balibu to find similar items.")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(viewModel.sessions) { session in
                    NavigationLink {
                        ResultsView(session: session)
                    } label: {
                        HistoryRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.background)
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let session: SearchSession
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            if let image = session.sourceImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            } else {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(DesignTokens.Colors.surfaceSecondary)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
            }
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                if let query = session.generatedQuery {
                    Text(query)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.text)
                        .lineLimit(2)
                } else {
                    Text("Search")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.text)
                }
                Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }
}

#Preview {
    NavigationStack {
        SearchHistoryView()
    }
}
