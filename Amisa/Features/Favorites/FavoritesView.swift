//
//  FavoritesView.swift
//

import SwiftUI

/// Racine : `NavigationStack` fourni par `MainTabContainerView`.
struct FavoritesView: View {
    @EnvironmentObject private var router: Router
    @State private var records: [FavoriteSearchRecord] = []

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 20
            let columnSpacing: CGFloat = 12
            let availableWidth = proxy.size.width
            let cardWidth = floor((availableWidth - horizontalPadding * 2 - columnSpacing) / 2)

            ScrollView {
                if records.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 130)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.fixed(cardWidth), spacing: columnSpacing),
                            GridItem(.fixed(cardWidth), spacing: columnSpacing),
                        ],
                        alignment: .center,
                        spacing: 14
                    ) {
                        ForEach(records) { record in
                            Button {
                                router.navigateToResultsFromFavorite(session: record.toSearchSession())
                            } label: {
                                FavoriteCard(favorite: record, cardWidth: cardWidth)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 130)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color(.systemBackground))
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
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            Text(String(localized: "Tes favoris apparaîtront ici"))
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
        .padding(.horizontal, 24)
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
            .environmentObject(Router())
    }
}
