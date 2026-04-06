//
//  FavoritesView.swift
//  Balibu
//

import SwiftUI
import UIKit

struct FavoritesView: View {
    @EnvironmentObject private var router: Router
    @State private var records: [FavoriteSearchRecord] = []

    private let gridColumns = [
        GridItem(.flexible(), spacing: DesignTokens.spacingM),
        GridItem(.flexible(), spacing: DesignTokens.spacingM),
    ]

    var body: some View {
        Group {
            if records.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: DesignTokens.spacingM) {
                        ForEach(records) { record in
                            Button {
                                router.navigateToResultsFromFavorite(session: record.toSearchSession())
                            } label: {
                                FavoriteAnalysisCard(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(DesignTokens.spacingM)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.backgroundColor)
        .navigationTitle(String(localized: "Favoris"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            records = FavoriteSearchService.shared.allRecords()
        }
        .onChange(of: router.selectedTab) { _, new in
            if new == .favorites {
                records = FavoriteSearchService.shared.allRecords()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingL) {
            Image(systemName: "heart.slash")
                .font(.system(size: 44))
                .foregroundStyle(DesignTokens.textSecondary)
            Text(String(localized: "Aucun favori"))
                .font(DesignTokens.headlineFont)
                .foregroundStyle(DesignTokens.textPrimary)
            Text(String(localized: "Enregistre une recherche depuis les résultats pour la retrouver ici."))
                .font(DesignTokens.bodyFont)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.spacingXL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
            .environmentObject(Router())
    }
}
