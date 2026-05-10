import Combine
import SwiftUI
import UIKit

enum HomeDiscoveryFeedBuilder {
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0xDEADBEEF : seed }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    static func build(sessions: [SearchSession], favoriteIds: Set<UUID>) -> [MarketplaceListing] {
        let imageSessions = sessions.filter { $0.mode == .imageAnalysis }
        guard !imageSessions.isEmpty else { return [] }

        func sessionWeight(_ s: SearchSession) -> Double {
            let recency = s.createdAt.timeIntervalSince1970
            let hasResults = s.listings.isEmpty ? 0.0 : 40.0
            let fav = favoriteIds.contains(s.id) ? 25.0 : 0.0
            return recency * 0.000_000_1 + hasResults + fav
        }

        let ordered = imageSessions.sorted { sessionWeight($0) > sessionWeight($1) }

        let perSessionQueues: [[MarketplaceListing]] = ordered.map { session in
            var rng = SeededGenerator(seed: UInt64(truncatingIfNeeded: session.id.hashValue))
            return session.listings.shuffled(using: &rng)
        }

        var seen = Set<String>()
        var round = 0
        var interleaved: [MarketplaceListing] = []

        while interleaved.count < 72 {
            var progressed = false
            for q in perSessionQueues.indices {
                guard round < perSessionQueues[q].count else { continue }
                let listing = perSessionQueues[q][round]
                let key = "\(listing.source)|\(listing.id)"
                if !seen.contains(key) {
                    seen.insert(key)
                    interleaved.append(listing)
                    progressed = true
                }
            }
            if !progressed { break }
            round += 1
        }

        var rng = SeededGenerator(seed: UInt64(ordered.count &* 17 &+ interleaved.count))
        return interleaved.shuffled(using: &rng)
    }
}

struct DiscoveryHomeView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var viewModel = DiscoveryHomeViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: DesignTokens.spacingM),
        GridItem(.flexible(), spacing: DesignTokens.spacingM),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(String(localized: "Découvre des pièces à partir de tes analyses photo."))
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)

                if viewModel.feedListings.isEmpty {
                    emptyState
                        .padding(.horizontal, 24)
                } else {
                    LazyVGrid(columns: columns, spacing: DesignTokens.spacingM) {
                        ForEach(viewModel.feedListings) { listing in
                            ListingCardView(listing: listing)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "Découverte"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.load() }
        .onChange(of: router.path.count) { _, _ in viewModel.load() }
        .onChange(of: router.selectedTab) { _, new in
            if new == .home { viewModel.load() }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "photo.on.rectangle.angled",
            title: String(localized: "Rien à afficher"),
            message: String(localized: "Scanne un article pour lancer une analyse.")
        )
    }
}

@MainActor
final class DiscoveryHomeViewModel: ObservableObject {
    @Published private(set) var feedListings: [MarketplaceListing] = []

    func load() {
        let sessions = SearchHistoryService.shared.fetchSessions()
        let favIds = Set(FavoriteSearchService.shared.allRecords().map(\.id))
        feedListings = HomeDiscoveryFeedBuilder.build(sessions: sessions, favoriteIds: favIds)

        // Mise à jour asynchrone et non bloquante de l'icône dynamique de la tab bar
        DynamicTabIconStore.shared.updateIfNeeded(with: feedListings)
    }
}

#Preview {
    NavigationStack {
        DiscoveryHomeView()
            .environmentObject(Router())
    }
}
