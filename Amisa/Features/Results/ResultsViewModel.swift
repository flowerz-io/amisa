//
//  ResultsViewModel.swift
//  Balibu
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
    @Published var isLoadingMore: Bool = false
    @Published var hasMoreResults: Bool
    @Published private(set) var hasMoreVinted: Bool = false
    @Published var showStickyHeader: Bool = false
    @Published private(set) var initialResponseTimeMs: Int?

    @Published private(set) var currentPage: Int
    private var nextPageToFetch: Int
    private let paginationSearchText: String
    private var vintedPagination: VintedPaginationDTO?
    private let apiClient: any APIClientProtocol
    private var didRunBootstrap: Bool = false
    private let awaitsRailwayHydration: Bool

    private var activeSlowPollSessionId: String?
    @Published private(set) var slowProvidersInProgress: Bool = false

    private var loadedSession: SearchSession? {
        if case .loaded(let s) = state { return s }
        return nil
    }

    private(set) var needsInitialListingsBootstrap: Bool = false

    private var isInitialSearchPending: Bool {
        guard let s = loadedSession else { return false }
        return s.hydratingBackendResults
            || s.awaitsRailwayHydration
            || needsInitialListingsBootstrap
    }

    var shouldShowSlowProvidersBanner: Bool {
        slowProvidersInProgress
    }

    var shouldShowSkeletons: Bool {
        isInitialSearchPending || isLoadingMore
    }

    var shouldShowFullSkeletonGrid: Bool {
        shouldShowSkeletons && displayedListings.isEmpty
    }

    var shouldShowTrailingSkeletonTiles: Bool {
        false
    }

    var shouldShowPaginationProgress: Bool {
        isLoadingMore && !displayedListings.isEmpty && !isInitialSearchPending
    }

    var shouldShowEmptyGridState: Bool {
        guard case .loaded = state else { return false }
        return !shouldShowSkeletons && displayedListings.isEmpty
    }

    init(session: SearchSession, apiClient: any APIClientProtocol = APIConfig.apiClient) {
        self.apiClient = apiClient
        self.awaitsRailwayHydration = session.awaitsRailwayHydration
        self.paginationSearchText = session.vintedPaginationQuery
        self.allListings = Self.sortByRelevance(session.listings)
        self.displayedListings = []
        self.vintedPagination = session.vintedPagination
        self.initialResponseTimeMs = session.initialResponseTimeMs

        self.activeSlowPollSessionId = session.searchSessionId
        self.slowProvidersInProgress =
            session.searchSessionId.map { !$0.isEmpty } ?? false
            && session.awaitsRailwayHydration

        if let p = session.vintedPagination {
            self.currentPage = max(1, p.nextPage - 1)
            self.nextPageToFetch = p.nextPage
            self.hasMoreVinted = p.hasMore
            self.hasMoreResults = p.hasMore
            self.state = .loaded(session)
        } else if session.listings.isEmpty {
            let q = session.vintedPaginationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if session.awaitsRailwayHydration || session.hydratingBackendResults {
                self.nextPageToFetch = 2
                self.currentPage = 1
                self.hasMoreResults = false
                self.hasMoreVinted = false
                self.state = .loaded(session)
                self.isLoadingMore = true
            } else if q.isEmpty {
                self.nextPageToFetch = 2
                self.currentPage = 1
                self.hasMoreResults = false
                self.hasMoreVinted = false
                self.state = .empty
            } else {
                self.nextPageToFetch = 2
                self.currentPage = 0
                self.hasMoreResults = true
                self.hasMoreVinted = true
                self.needsInitialListingsBootstrap = true
                self.state = .loaded(session)
            }
        } else {
            self.nextPageToFetch = 2
            self.currentPage = 1
            let q = session.vintedPaginationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let n = session.listings.count
            let more = !q.isEmpty && n > 0
            self.hasMoreResults = more
            self.hasMoreVinted = more
            self.state = .loaded(session)
        }

        applyDisplayedListings()
    }

    func mergeHydratedBackendResults(_ session: SearchSession) {
        guard case .loaded(let current) = state, current.id == session.id else { return }
        guard current.hydratingBackendResults else { return }

        allListings = Self.sortByRelevance(session.listings)
        vintedPagination = session.vintedPagination
        initialResponseTimeMs = session.initialResponseTimeMs

        if let p = session.vintedPagination {
            currentPage = max(1, p.nextPage - 1)
            nextPageToFetch = p.nextPage
            hasMoreVinted = p.hasMore
            hasMoreResults = p.hasMore
            needsInitialListingsBootstrap = false
            state = .loaded(session)
            isLoadingMore = false
        } else if session.listings.isEmpty {
            nextPageToFetch = 2
            currentPage = 1
            hasMoreResults = false
            hasMoreVinted = false
            needsInitialListingsBootstrap = false
            state = .loaded(session)
            isLoadingMore = false
        } else {
            nextPageToFetch = 2
            currentPage = 1
            let q = session.vintedPaginationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let more = !q.isEmpty && !session.listings.isEmpty
            hasMoreResults = more
            hasMoreVinted = more
            needsInitialListingsBootstrap = false
            state = .loaded(session)
            isLoadingMore = false
        }

        slowProvidersInProgress = false
        applyDisplayedListings()
    }

    func mergeSlowPoll(_ response: AnalyzeSearchResponse, httpPollStatus: String?) {
        guard case .loaded(var session) = state else { return }
        let merged = response.listings.map { MarketplaceListing.from($0) }
        allListings = Self.sortByRelevance(merged)
        session.listings = allListings
        vintedPagination = response.pagination
        if let sid = response.searchSessionId, !sid.isEmpty {
            session.searchSessionId = sid
            activeSlowPollSessionId = sid
        }
        let done =
            response.status == "completed"
            || httpPollStatus == "completed"
            || httpPollStatus == "failed"
        if done {
            session.searchSessionId = nil
            activeSlowPollSessionId = nil
            slowProvidersInProgress = false
        }
        if let p = response.pagination {
            currentPage = max(1, p.nextPage - 1)
            nextPageToFetch = p.nextPage
            hasMoreVinted = p.hasMore
            hasMoreResults = p.hasMore
        }
        state = .loaded(session)
        applyDisplayedListings()
    }

    func pollSlowSearchSessionIfNeeded() async {
        let sid = activeSlowPollSessionId ?? loadedSession?.searchSessionId
        guard let sid, !sid.isEmpty else { return }
        guard slowProvidersInProgress else { return }
        let deadline = Date().addingTimeInterval(45)
        while Date() < deadline {
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            do {
                let poll = try await apiClient.fetchSearchSessionStatus(sessionId: sid)
                if poll.status == "failed" {
                    await MainActor.run { slowProvidersInProgress = false }
                    return
                }
                if let r = poll.response {
                    await MainActor.run {
                        mergeSlowPoll(r, httpPollStatus: poll.status)
                    }
                    if poll.status == "completed" || r.status == "completed" {
                        return
                    }
                }
            } catch {
                await MainActor.run { slowProvidersInProgress = false }
                return
            }
        }
        await MainActor.run { slowProvidersInProgress = false }
    }

    func applyHydrationFailure(message: String) {
        guard case .loaded(let current) = state, current.hydratingBackendResults else { return }
        if !allListings.isEmpty {
            var cleared = current
            cleared.hydratingBackendResults = false
            state = .loaded(cleared)
            isLoadingMore = false
            return
        }
        state = .error(message)
        isLoadingMore = false
    }

    func bootstrapInitialListingsIfNeeded() async {
        guard !awaitsRailwayHydration else { return }
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
            applyDisplayedListings()
            currentPage = response.page
            nextPageToFetch = 2
            hasMoreResults = response.hasMore
            hasMoreVinted = response.hasMore
        } catch {
            hasMoreResults = false
            hasMoreVinted = false
        }
    }

    func updateHeroVisibility(minY: CGFloat) {
        showStickyHeader = minY < -36
    }

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

        do {
            let response = try await apiClient.fetchVintedListingsPage(
                searchText: paginationSearchText,
                page: nextPageToFetch
            )
            let newItems = response.listings.map { MarketplaceListing.from($0) }
            allListings = Self.mergeUnique(existing: allListings, new: newItems)
            allListings = Self.sortByRelevance(allListings)
            applyDisplayedListings()
            currentPage = response.page
            nextPageToFetch += 1
            hasMoreResults = response.hasMore
            hasMoreVinted = response.hasMore
        } catch {
            hasMoreResults = false
            hasMoreVinted = false
        }
    }

    var availableMarketplaceSources: [String] {
        ["Vinted"]
    }

    var totalListingsCount: Int {
        max(allListings.count, displayedListings.count)
    }

    func formatListingsCount(_ count: Int) -> String {
        Self.frenchIntegerFormatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    var formattedTotalListingsCount: String {
        formatListingsCount(totalListingsCount)
    }

    var formattedInitialSearchTime: String? {
        guard let ms = initialResponseTimeMs, ms >= 0 else { return nil }
        let seconds = Double(ms) / 1000.0
        let number = Self.frenchOneDecimalFormatter.string(from: NSNumber(value: seconds))
            ?? String(format: "%.1f", seconds).replacingOccurrences(of: ".", with: ",")
        return "\(number) s"
    }

    private func applyDisplayedListings() {
        displayedListings = allListings
        #if DEBUG
        if case .loaded = state {
            print("[ResultsUI] listings=\(displayedListings.count) skeletons=\(shouldShowSkeletons)")
        }
        #endif
    }

    private static let frenchIntegerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let frenchOneDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private static func listingMergeKey(_ listing: MarketplaceListing) -> String {
        let src = MarketplaceSource.canonicalKey(from: listing.source)
        let id = listing.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if !src.isEmpty && !id.isEmpty { return "ext:\(src)|\(id)" }
        let url = listing.listingURL?.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !src.isEmpty && !url.isEmpty { return "url:\(src)|\(url)" }
        if !url.isEmpty { return "url:\(url)" }
        return "fallback:\(src)|\(id)"
    }

    private static func mergeUnique(existing: [MarketplaceListing], new: [MarketplaceListing]) -> [MarketplaceListing] {
        var seen = Set<String>()
        for x in existing { seen.insert(listingMergeKey(x)) }
        var out = existing
        for x in new {
            let k = listingMergeKey(x)
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
}
