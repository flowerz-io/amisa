//
//  FavoritesView.swift
//  Balibu
//

import SwiftUI
import UIKit

struct FavoritesView: View {
    @EnvironmentObject private var router: Router
    @State private var records: [FavoriteSearchRecord] = []

    var body: some View {
        Group {
            if records.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(records) { record in
                        Button {
                            router.navigateToResultsFromFavorite(session: record.toSearchSession())
                        } label: {
                            FavoriteRowView(record: record)
                        }
                    }
                }
                .listStyle(.insetGrouped)
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
            if new == .profile {
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

private struct FavoriteRowView: View {
    let record: FavoriteSearchRecord

    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            thumbnail
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusS, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(record.searchQuery)
                    .font(DesignTokens.bodyFont)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(2)
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(DesignTokens.captionFont)
                    .foregroundStyle(DesignTokens.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbURL = record.thumbnailImageURL,
           let data = try? Data(contentsOf: thumbURL),
           let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else if let name = record.imageFileName,
                  let ui = ImagePersistenceService.shared.loadUIImage(fileName: name) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusS, style: .continuous)
                .fill(DesignTokens.accentMuted)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(DesignTokens.textSecondary)
                }
        }
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
            .environmentObject(Router())
    }
}
