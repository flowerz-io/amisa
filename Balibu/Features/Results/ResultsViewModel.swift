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
    @Published private(set) var allListings: [MarketplaceListing]
    @Published var enabledProviderKeys: Set<String> {
        didSet {
            applyDisplayedFilters()
            logPaginationState(context: "providers_filter_changed")
        }
    }
    @Published var isLoadingMore: Bool = false
    @Published var hasMoreResults: Bool
    @Published var hasMoreVinted: Bool = false
    @Published var hasMoreGrailed: Bool = false
    @Published var showStickyHeader: Bool = false
    /// Historique debug : page Vinted courante (legacy + nouveau flow).
    @Published private(set) var currentPage: Int
    /// Liste vide au chargement mais requête Vinted disponible (favori) : première page à charger.
    private(set) var needsInitialListingsBootstrap: Bool = false

    private var nextPageToFetch: Int
    private let paginationSearchText: String
    private var paginationState: SearchPaginationStateDTO?
    private var rankingContext: SearchRankingContextDTO?
    private let apiClient: any APIClientProtocol
    private var didRunBootstrap: Bool = false

    init(session: SearchSession, apiClient: any APIClientProtocol = APIConfig.apiClient) {
        self.apiClient = apiClient
        self.paginationSearchText = session.vintedPaginationQuery
        self.allListings = Self.sortByRelevance(session.listings)
        self.enabledProviderKeys = Set(MarketplaceSource.knownProviderDisplayNames.map { MarketplaceSource.canonicalKey(from: $0) })
        self.displayedListings = []
        self.paginationState = session.paginationState
        self.rankingContext = session.rankingContext

        if let paginationState = session.paginationState {
            self.currentPage = max(1, paginationState.vinted.nextPage - 1)
            self.nextPageToFetch = paginationState.vinted.nextPage
            self.hasMoreVinted = paginationState.vinted.hasMore
            self.hasMoreGrailed = paginationState.grailed.hasMore
            self.hasMoreResults = paginationState.vinted.hasMore || paginationState.grailed.hasMore
            self.state = .loaded(session)
        } else if session.listings.isEmpty {
            let q = session.vintedPaginationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if q.isEmpty {
                self.nextPageToFetch = 2
                self.currentPage = 1
                self.hasMoreResults = false
                self.hasMoreVinted = false
                self.hasMoreGrailed = false
                self.state = .empty
            } else {
                self.nextPageToFetch = 2
                self.currentPage = 0
                self.hasMoreResults = true
                self.hasMoreVinted = true
                self.hasMoreGrailed = false
                self.needsInitialListingsBootstrap = true
                self.state = .loaded(session)
            }
        } else {
            self.nextPageToFetch = 2
            self.currentPage = 1
            let q = session.vintedPaginationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let vintedOnFirstLoad = session.listings.filter { $0.source == "Vinted" }.count
            let more = !q.isEmpty && vintedOnFirstLoad > 0
            self.hasMoreResults = more
            self.hasMoreVinted = more
            self.hasMoreGrailed = false
            self.state = .loaded(session)
        }

        applyDisplayedFilters()
        logPaginationState(context: "init")
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
            allListings = Self.sortByRelevance(newItems)
            applyDisplayedFilters()
            currentPage = response.page
            nextPageToFetch = 2
            hasMoreResults = response.hasMore
            hasMoreVinted = response.hasMore
            hasMoreGrailed = false
        } catch {
            hasMoreResults = false
            hasMoreVinted = false
            hasMoreGrailed = false
        }
        logPaginationState(context: "bootstrap_done")
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

        Task { await loadNextBatch() }
    }

    private func loadNextBatch() async {
        guard !isLoadingMore, hasMoreResults else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        if let paginationState, let rankingContext {
            do {
                let response = try await apiClient.fetchSearchMore(
                    request: SearchMoreRequest(
                        primaryQuery: paginationState.primaryQuery,
                        batchSizePerProvider: paginationState.batchSizePerProvider,
                        pagination: paginationState,
                        rankingContext: rankingContext
                    )
                )
                let newItems = response.listings.map { MarketplaceListing.from($0) }
                allListings = Self.mergeUnique(existing: allListings, new: newItems)
                allListings = Self.sortByRelevance(allListings)
                applyDisplayedFilters()

                self.paginationState = response.pagination
                currentPage = max(1, response.pagination.vinted.nextPage - 1)
                nextPageToFetch = response.pagination.vinted.nextPage
                hasMoreVinted = response.hasMoreVinted
                hasMoreGrailed = response.hasMoreGrailed
                hasMoreResults = response.hasMoreVinted || response.hasMoreGrailed
            } catch {
                hasMoreResults = false
                hasMoreVinted = false
                hasMoreGrailed = false
            }
            logPaginationState(context: "loadNextBatch_searchMore_done")
            return
        }

        do {
            let response = try await apiClient.fetchVintedListingsPage(
                searchText: paginationSearchText,
                page: nextPageToFetch
            )
            let newItems = response.listings.map { MarketplaceListing.from($0) }
            allListings = Self.mergeUnique(existing: allListings, new: newItems)
            allListings = Self.sortByRelevance(allListings)
            applyDisplayedFilters()
            currentPage = response.page
            nextPageToFetch += 1
            hasMoreResults = response.hasMore
            hasMoreVinted = response.hasMore
            hasMoreGrailed = false
        } catch {
            hasMoreResults = false
            hasMoreVinted = false
            hasMoreGrailed = false
        }
        logPaginationState(context: "loadNextBatch_legacy_done")
    }

    var availableMarketplaceSources: [String] {
        var ordered: [String] = []
        var seen = Set<String>()

        for known in MarketplaceSource.knownProviderDisplayNames {
            let key = MarketplaceSource.canonicalKey(from: known)
            if !seen.contains(key) {
                seen.insert(key)
                ordered.append(known)
            }
        }

        for listing in allListings {
            let key = MarketplaceSource.canonicalKey(from: listing.source)
            if !seen.contains(key) {
                seen.insert(key)
                ordered.append(listing.sourceDisplayLabel)
            }
        }
        return ordered
    }

    private func applyDisplayedFilters() {
        displayedListings = allListings.filter { listing in
            enabledProviderKeys.contains(MarketplaceSource.canonicalKey(from: listing.source))
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

    private static func sortByRelevance(_ listings: [MarketplaceListing]) -> [MarketplaceListing] {
        listings.sorted { lhs, rhs in
            (lhs.relevanceScore ?? 0) > (rhs.relevanceScore ?? 0)
        }
    }

    private func logPaginationState(context: String) {
        let vinted = allListings.filter { $0.source == "Vinted" }.count
        let grailed = allListings.filter { $0.source == "Grailed" }.count
        let ebay = allListings.filter { MarketplaceSource.canonicalKey(from: $0.source) == "ebay" }.count
        let leboncoin = allListings.filter { MarketplaceSource.canonicalKey(from: $0.source) == "leboncoin" }.count
        print(
            "[RESULTS_VM] \(context) currentPage=\(currentPage) hasMore=\(hasMoreResults) hasMoreVinted=\(hasMoreVinted) hasMoreGrailed=\(hasMoreGrailed) isLoadingMore=\(isLoadingMore) displayedListings.count=\(displayedListings.count) allListings.count=\(allListings.count) vinted=\(vinted) grailed=\(grailed) ebay=\(ebay) leboncoin=\(leboncoin)"
        )
    }
}
