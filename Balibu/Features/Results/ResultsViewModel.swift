//
//  ResultsViewModel.swift
//  Balibu
//
//  État Results : liste affichée, pagination Vinted, barre sticky.
//

import SwiftUI
import Combine

enum ResultsViewState: Equatable {
    case loaded(SearchSession)
    case empty
    case error(String)
}

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var state: ResultsViewState
    @Published var displayedListings: [MarketplaceListing]
    @Published var isLoadingMore: Bool = false
    @Published var hasMoreResults: Bool
    @Published var showStickyHeader: Bool = false
    /// Dernière page Vinted déjà chargée avec succès (la page 1 vient de `analyze-search` ou du bootstrap favori).
    @Published private(set) var currentPage: Int
    /// Liste vide au chargement mais requête Vinted disponible (favori) : première page à charger.
    private(set) var needsInitialListingsBootstrap: Bool = false

    private var nextPageToFetch: Int
    private let paginationSearchText: String
    private let apiClient: any APIClientProtocol
    private var didRunBootstrap: Bool = false

    init(session: SearchSession, apiClient: any APIClientProtocol = APIConfig.apiClient) {
        self.apiClient = apiClient
        self.paginationSearchText = session.vintedPaginationQuery
        self.displayedListings = session.listings

        if session.listings.isEmpty {
            let q = session.vintedPaginationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if q.isEmpty {
                self.nextPageToFetch = 2
                self.currentPage = 1
                self.hasMoreResults = false
                self.state = .empty
            } else {
                self.nextPageToFetch = 2
                self.currentPage = 0
                self.hasMoreResults = true
                self.needsInitialListingsBootstrap = true
                self.state = .loaded(session)
            }
        } else {
            self.nextPageToFetch = 2
            self.currentPage = 1
            let canPaginate = !session.vintedPaginationQuery.isEmpty && session.listings.count >= 10
            self.hasMoreResults = canPaginate
            self.state = .loaded(session)
        }
    }

    /// Favori sans annonces : recharge la page 1 Vinted avec la même logique que la pagination existante.
    func bootstrapInitialListingsIfNeeded() async {
        guard needsInitialListingsBootstrap, !didRunBootstrap else { return }
        guard case .loaded = state else { return }
        didRunBootstrap = true
        needsInitialListingsBootstrap = false
        guard !paginationSearchText.isEmpty else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await apiClient.fetchVintedListingsPage(
                searchText: paginationSearchText,
                page: 1
            )
            let newItems = response.listings.map { MarketplaceListing.from($0) }
            displayedListings = newItems
            currentPage = response.page
            nextPageToFetch = 2
            hasMoreResults = response.hasMore
        } catch {
            hasMoreResults = false
        }
    }

    func updateHeroVisibility(minY: CGFloat) {
        showStickyHeader = minY < -36
    }

    /// Chargement anticipé : vers ~50 % de la liste (ex. 5ᵉ carte sur 10).
    func loadMoreIfNeeded(currentItem: MarketplaceListing) {
        guard case .loaded = state else { return }
        guard hasMoreResults, !isLoadingMore else { return }
        guard !paginationSearchText.isEmpty else { return }
        guard let idx = displayedListings.firstIndex(where: { $0.id == currentItem.id }) else { return }

        let threshold = max(0, displayedListings.count / 2 - 1)
        guard idx >= threshold else { return }

        Task { await loadNextPage() }
    }

    private func loadNextPage() async {
        guard !isLoadingMore, hasMoreResults else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await apiClient.fetchVintedListingsPage(
                searchText: paginationSearchText,
                page: nextPageToFetch
            )
            let newItems = response.listings.map { MarketplaceListing.from($0) }
            displayedListings = Self.mergeUnique(existing: displayedListings, new: newItems)
            currentPage = response.page
            nextPageToFetch += 1
            hasMoreResults = response.hasMore
        } catch {
            hasMoreResults = false
        }
    }

    private static func mergeUnique(existing: [MarketplaceListing], new: [MarketplaceListing]) -> [MarketplaceListing] {
        var seen = Set<String>()
        for x in existing { seen.insert("\(x.source)|\(x.id)") }
        var out = existing
        for x in new {
            let k = "\(x.source)|\(x.id)"
            if !seen.contains(k) {
                seen.insert(k)
                out.append(x)
            }
        }
        return out
    }
}
