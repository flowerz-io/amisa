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
    /// Affiche tous les `listings` renvoyés par l’API (aucune troncature locale type 30). `APIConfig.maxResultsPerSearch` mirror le plafond backend (`MAX_RESULTS_PER_SEARCH`, défaut 100).
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
    @Published var hasMoreEbay: Bool = false
    @Published var hasMoreLeboncoin: Bool = false
    @Published var hasMoreDepop: Bool = false
    @Published var showStickyHeader: Bool = false
    /// Disponibilité providers (ex. eBay bloqué par challenge).
    @Published private(set) var providerAvailabilityMap: ProviderAvailabilityMapDTO?
    /// Compteurs totaux backend par provider (source de vérité pour l’UI).
    @Published private(set) var providerCounts: ProviderCountsDTO
    /// Temps backend (ms) pour la première vague de résultats.
    @Published private(set) var initialResponseTimeMs: Int?
    /// Réponse snapshot avant fin de tous les providers (early cutoff serveur).
    @Published private(set) var moreProvidersPending: Bool = false
    /// Poll `search-sessions` tant que le backend indique une phase lente active.
    @Published private(set) var slowProvidersInProgress: Bool = false

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
    private let awaitsRailwayHydration: Bool

    private var activeSlowPollSessionId: String?

    // MARK: - Grille : skeletons / vide (UX recherche)

    private var loadedSession: SearchSession? {
        if case .loaded(let s) = state { return s }
        return nil
    }

    /// Recherche initiale ou snapshot encore incomplet (ne couvre pas la pagination « load more » seule).
    private var isInitialSearchPending: Bool {
        guard let s = loadedSession else { return false }
        return s.hydratingBackendResults
            || s.awaitsRailwayHydration
            || needsInitialListingsBootstrap
    }

    /// Bandeau discret : providers lents (Depop / Grailed) encore en cours.
    var shouldShowSlowProvidersBanner: Bool {
        slowProvidersInProgress
    }

    /// Grille : shimmer tant que l’une des sources ci-dessus est active ou qu’un chargement réseau est en cours.
    var shouldShowSkeletons: Bool {
        isInitialSearchPending || isLoadingMore
    }

    var shouldShowFullSkeletonGrid: Bool {
        shouldShowSkeletons && displayedListings.isEmpty
    }

    /// Résultats déjà affichés mais vague partielle (providers encore à fusionner côté backend).
    var shouldShowTrailingSkeletonTiles: Bool {
        !displayedListings.isEmpty && isInitialSearchPending
    }

    var shouldShowPaginationProgress: Bool {
        isLoadingMore && !displayedListings.isEmpty && !isInitialSearchPending
    }

    /// Message « aucune annonce » dans la page résultats (pas l’écran `.empty` du VM).
    var shouldShowEmptyGridState: Bool {
        guard case .loaded = state else { return false }
        return !shouldShowSkeletons && displayedListings.isEmpty
    }

    init(session: SearchSession, apiClient: any APIClientProtocol = APIConfig.apiClient) {
        self.apiClient = apiClient
        self.awaitsRailwayHydration = session.awaitsRailwayHydration
        self.paginationSearchText = session.vintedPaginationQuery
        self.allListings = Self.sortByRelevance(session.listings)
        self.enabledProviderKeys = Set(
            ProviderSettingsStore.enabledProviderBackendKeysSnapshot().map {
                MarketplaceSource.canonicalKey(from: $0)
            }
        )
        self.displayedListings = []
        self.paginationState = session.paginationState
        self.rankingContext = session.rankingContext
        self.providerCounts = session.providerCounts ?? Self.providerCounts(from: session.paginationState)
        self.initialResponseTimeMs = session.initialResponseTimeMs
        self.moreProvidersPending = session.moreProvidersPending
        self.activeSlowPollSessionId = session.searchSessionId
        self.slowProvidersInProgress =
            session.searchSessionId != nil
            && session.searchSessionId?.isEmpty == false
            && session.moreProvidersPending

        if let paginationState = session.paginationState {
            self.currentPage = max(1, paginationState.vinted.nextPage - 1)
            self.nextPageToFetch = paginationState.vinted.nextPage
            self.hasMoreVinted = paginationState.vinted.hasMore
            self.hasMoreGrailed = paginationState.grailed.hasMore
            self.hasMoreEbay = paginationState.ebay?.hasMore ?? false
            self.hasMoreLeboncoin = paginationState.leboncoin?.hasMore ?? false
            self.hasMoreDepop = paginationState.depop?.hasMore ?? false
            self.hasMoreResults =
                paginationState.vinted.hasMore ||
                paginationState.grailed.hasMore ||
                (paginationState.ebay?.hasMore ?? false) ||
                (paginationState.leboncoin?.hasMore ?? false) ||
                (paginationState.depop?.hasMore ?? false)
            self.state = .loaded(session)
        } else if session.listings.isEmpty {
            let q = session.vintedPaginationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if session.awaitsRailwayHydration || session.hydratingBackendResults {
                self.nextPageToFetch = 2
                self.currentPage = 1
                self.hasMoreResults = false
                self.hasMoreVinted = false
                self.hasMoreGrailed = false
                self.hasMoreEbay = false
                self.hasMoreLeboncoin = false
                self.hasMoreDepop = false
                self.state = .loaded(session)
                self.isLoadingMore = true
            } else if q.isEmpty {
                self.nextPageToFetch = 2
                self.currentPage = 1
                self.hasMoreResults = false
                self.hasMoreVinted = false
                self.hasMoreGrailed = false
                self.hasMoreEbay = false
                self.hasMoreLeboncoin = false
                self.hasMoreDepop = false
                self.state = .empty
            } else {
                self.nextPageToFetch = 2
                self.currentPage = 0
                self.hasMoreResults = true
                self.hasMoreVinted = true
                self.hasMoreGrailed = false
                self.hasMoreEbay = false
                self.hasMoreLeboncoin = false
                self.hasMoreDepop = false
                self.needsInitialListingsBootstrap = true
                self.state = .loaded(session)
            }
        } else {
            self.nextPageToFetch = 2
            self.currentPage = 1
            let q = session.vintedPaginationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let vintedOnFirstLoad = session.listings.filter { MarketplaceSource.canonicalKey(from: $0.source) == "vinted" }.count
            let more = !q.isEmpty && vintedOnFirstLoad > 0
            self.hasMoreResults = more
            self.hasMoreVinted = more
            self.hasMoreGrailed = false
            self.hasMoreEbay = false
            self.hasMoreLeboncoin = false
            self.hasMoreDepop = false
            self.state = .loaded(session)
        }

        self.providerAvailabilityMap = session.providerAvailability
        ProviderRuntimeAvailabilityStore.shared.merge(from: session.providerAvailability)

        applyDisplayedFilters()
        logPaginationState(context: "init")
    }

    /// Fusionne la réponse réelle après ouverture Results avec placeholder (`hydratingBackendResults`).
    func mergeHydratedBackendResults(_ session: SearchSession) {
        guard case .loaded(let current) = state, current.id == session.id else { return }
        guard current.hydratingBackendResults else { return }

        allListings = Self.sortByRelevance(session.listings)
        paginationState = session.paginationState
        rankingContext = session.rankingContext
        providerCounts = session.providerCounts ?? Self.providerCounts(from: session.paginationState)
        initialResponseTimeMs = session.initialResponseTimeMs
        moreProvidersPending = session.moreProvidersPending
        slowProvidersInProgress =
            session.searchSessionId != nil
            && !(session.searchSessionId?.isEmpty ?? true)
            && session.moreProvidersPending
        activeSlowPollSessionId = session.searchSessionId
        providerAvailabilityMap = session.providerAvailability
        ProviderRuntimeAvailabilityStore.shared.merge(from: session.providerAvailability)

        if let paginationState = session.paginationState {
            currentPage = max(1, paginationState.vinted.nextPage - 1)
            nextPageToFetch = paginationState.vinted.nextPage
            hasMoreVinted = paginationState.vinted.hasMore
            hasMoreGrailed = paginationState.grailed.hasMore
            hasMoreEbay = paginationState.ebay?.hasMore ?? false
            hasMoreLeboncoin = paginationState.leboncoin?.hasMore ?? false
            hasMoreDepop = paginationState.depop?.hasMore ?? false
            hasMoreResults = hasMoreFromAllProviders()
            needsInitialListingsBootstrap = false
            state = .loaded(session)
            isLoadingMore = false
        } else if session.listings.isEmpty {
            nextPageToFetch = 2
            currentPage = 1
            hasMoreResults = false
            hasMoreVinted = false
            hasMoreGrailed = false
            hasMoreEbay = false
            hasMoreLeboncoin = false
            hasMoreDepop = false
            needsInitialListingsBootstrap = false
            state = .loaded(session)
            isLoadingMore = false
        } else {
            nextPageToFetch = 2
            currentPage = 1
            let q = session.vintedPaginationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let vintedOnFirstLoad = session.listings.filter { MarketplaceSource.canonicalKey(from: $0.source) == "vinted" }.count
            let more = !q.isEmpty && vintedOnFirstLoad > 0
            hasMoreResults = more
            hasMoreVinted = more
            hasMoreGrailed = false
            hasMoreEbay = false
            hasMoreLeboncoin = false
            hasMoreDepop = false
            needsInitialListingsBootstrap = false
            state = .loaded(session)
            isLoadingMore = false
        }

        applyDisplayedFilters()
        logPaginationState(context: "hydration_merge")
    }

    func mergeSlowPoll(_ response: AnalyzeSearchResponse, httpPollStatus: String?) {
        guard case .loaded(var session) = state else { return }
        let merged = response.listings.map { MarketplaceListing.from($0) }
        allListings = Self.sortByRelevance(merged)
        moreProvidersPending = response.moreProvidersPending ?? false
        session.listings = allListings
        session.moreProvidersPending = moreProvidersPending
        session.providerStatuses = response.providerStatuses ?? session.providerStatuses
        if let sid = response.searchSessionId, !sid.isEmpty {
            session.searchSessionId = sid
            activeSlowPollSessionId = sid
        }
        let done =
            response.status == "completed"
            || httpPollStatus == "completed"
            || httpPollStatus == "failed"
            || !moreProvidersPending
        if done {
            session.searchSessionId = nil
            activeSlowPollSessionId = nil
            slowProvidersInProgress = false
        } else {
            slowProvidersInProgress =
                session.searchSessionId != nil
                && !(session.searchSessionId?.isEmpty ?? true)
                && moreProvidersPending
        }
        state = .loaded(session)
        applyDisplayedFilters()
        logPaginationState(context: "slow_poll_merge")
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
                    await MainActor.run {
                        slowProvidersInProgress = false
                    }
                    return
                }
                if let r = poll.response {
                    await MainActor.run {
                        mergeSlowPoll(r, httpPollStatus: poll.status)
                    }
                    let terminal =
                        poll.status == "completed"
                        || r.status == "completed"
                        || !(r.moreProvidersPending ?? false)
                    if terminal {
                        return
                    }
                }
            } catch {
                await MainActor.run {
                    slowProvidersInProgress = false
                }
                return
            }
        }
        await MainActor.run {
            slowProvidersInProgress = false
        }
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

    /// Favori sans annonces : recharge la page 1 Vinted avec la même logique que la pagination existante.
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
            applyDisplayedFilters()
            currentPage = response.page
            nextPageToFetch = 2
            hasMoreResults = response.hasMore
            hasMoreVinted = response.hasMore
            hasMoreGrailed = false
            hasMoreEbay = false
            hasMoreLeboncoin = false
            hasMoreDepop = false
        } catch {
            hasMoreResults = false
            hasMoreVinted = false
            hasMoreGrailed = false
            hasMoreEbay = false
            hasMoreLeboncoin = false
            hasMoreDepop = false
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
                        rankingContext: rankingContext,
                        enabledProviders: ProviderSettingsStore.enabledProviderBackendKeysSnapshot()
                    )
                )
                if let delta = response.providerAvailability {
                    providerAvailabilityMap = (providerAvailabilityMap ?? ProviderAvailabilityMapDTO()).merged(with: delta)
                    ProviderRuntimeAvailabilityStore.shared.merge(from: delta)
                }
                let newItems = response.listings.map { MarketplaceListing.from($0) }
                allListings = Self.mergeUnique(existing: allListings, new: newItems)
                allListings = Self.sortByRelevance(allListings)
                applyDisplayedFilters()

                self.paginationState = response.pagination
                providerCounts = providerCounts
                    .merged(with: Self.providerCounts(from: response.pagination))
                    .merged(with: response.providerCounts)
                currentPage = max(1, response.pagination.vinted.nextPage - 1)
                nextPageToFetch = response.pagination.vinted.nextPage
                hasMoreVinted = response.hasMoreVinted
                hasMoreGrailed = response.hasMoreGrailed
                hasMoreEbay = response.hasMoreEbay ?? false
                hasMoreLeboncoin = response.hasMoreLeboncoin ?? false
                hasMoreDepop = response.hasMoreDepop ?? false
                hasMoreResults = hasMoreFromAllProviders()
            } catch {
                hasMoreResults = false
                hasMoreVinted = false
                hasMoreGrailed = false
                hasMoreEbay = false
                hasMoreLeboncoin = false
                hasMoreDepop = false
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
            hasMoreEbay = false
            hasMoreLeboncoin = false
            hasMoreDepop = false
        } catch {
            hasMoreResults = false
            hasMoreVinted = false
            hasMoreGrailed = false
            hasMoreEbay = false
            hasMoreLeboncoin = false
            hasMoreDepop = false
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

    var totalListingsCount: Int {
        let total = providerCounts.sum
        return total > 0 ? total : displayedListings.count
    }

    func providerTotalCount(for source: String) -> Int {
        providerCounts.count(for: source) ?? 0
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

    private func applyDisplayedFilters() {
        displayedListings = allListings.filter { listing in
            if isEbayHiddenWhenBlocked(listing) { return false }
            return enabledProviderKeys.contains(MarketplaceSource.canonicalKey(from: listing.source))
        }
        #if DEBUG
        logResultsUIDebug()
        #endif
    }

    #if DEBUG
    private func logResultsUIDebug() {
        guard case .loaded = state else { return }
        let status = shouldShowSkeletons ? "running" : "completed"
        print(
            "[ResultsUI] status=\(status) listings=\(displayedListings.count) showSkeletons=\(shouldShowSkeletons) showEmpty=\(shouldShowEmptyGridState)"
        )
    }
    #endif

    private func isEbayHiddenWhenBlocked(_ listing: MarketplaceListing) -> Bool {
        guard MarketplaceSource.canonicalKey(from: listing.source) == "ebay" else { return false }
        return providerAvailabilityMap?.ebay?.status == .blocked_by_challenge
    }

    private func hasMoreFromAllProviders() -> Bool {
        hasMoreVinted || hasMoreGrailed || hasMoreEbay || hasMoreLeboncoin || hasMoreDepop
    }

    private static func providerCounts(from pagination: SearchPaginationStateDTO?) -> ProviderCountsDTO {
        ProviderCountsDTO(
            vinted: pagination?.vinted.totalCount ?? pagination?.vinted.loadedCount,
            grailed: pagination?.grailed.totalCount ?? pagination?.grailed.loadedCount,
            ebay: pagination?.ebay?.totalCount ?? pagination?.ebay?.loadedCount,
            leboncoin: pagination?.leboncoin?.totalCount ?? pagination?.leboncoin?.loadedCount,
            depop: pagination?.depop?.totalCount ?? pagination?.depop?.loadedCount
        )
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

    private func logPaginationState(context: String) {
        let vinted = allListings.filter { MarketplaceSource.canonicalKey(from: $0.source) == "vinted" }.count
        let grailed = allListings.filter { $0.source == "Grailed" }.count
        let ebay = allListings.filter { MarketplaceSource.canonicalKey(from: $0.source) == "ebay" }.count
        let leboncoin = allListings.filter { MarketplaceSource.canonicalKey(from: $0.source) == "leboncoin" }.count
        let depop = allListings.filter { MarketplaceSource.canonicalKey(from: $0.source) == "depop" }.count
        print(
            "[RESULTS_VM] \(context) currentPage=\(currentPage) hasMore=\(hasMoreResults) hasMoreVinted=\(hasMoreVinted) hasMoreGrailed=\(hasMoreGrailed) hasMoreEbay=\(hasMoreEbay) hasMoreLeboncoin=\(hasMoreLeboncoin) hasMoreDepop=\(hasMoreDepop) isLoadingMore=\(isLoadingMore) displayedListings.count=\(displayedListings.count) allListings.count=\(allListings.count) vinted=\(vinted) grailed=\(grailed) ebay=\(ebay) leboncoin=\(leboncoin) depop=\(depop)"
        )
    }
}

#if DEBUG
extension ResultsViewModel {
    /// Comptes par source sur les annonces fusionnées (hydratation incluse), pas sur la grille filtrée.
    var debugProviderListingCountsLine: String {
        let order: [(key: String, label: String)] = [
            ("ebay", "eBay"),
            ("vinted", "Vinted"),
            ("depop", "Depop"),
            ("grailed", "Grailed"),
        ]
        return order.map { item in
            let c = allListings.filter { MarketplaceSource.canonicalKey(from: $0.source) == item.key }.count
            return "\(item.label): \(c)"
        }.joined(separator: ", ")
    }

    /// Statuts backend récents (ex. `running`, `success`, `blocked`).
    var debugProviderStatusesLine: String? {
        guard let map = loadedSession?.providerStatuses, !map.isEmpty else { return nil }
        let order = ["ebay", "vinted", "depop", "grailed"]
        let parts = order.compactMap { key -> String? in
            guard let v = map[key] else { return nil }
            return "\(key)=\(v)"
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
#endif
