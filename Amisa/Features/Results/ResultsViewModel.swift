//
//  ResultsViewModel.swift
//  Balibu
//

import Combine
import simd
import SwiftUI

enum ResultsViewState: Equatable {
    case loaded(SearchSession)
    case empty
    case error(String)
}

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var state: ResultsViewState
    @Published private(set) var displayedListings: [MarketplaceListing]
    @Published private(set) var allListings: [MarketplaceListing]
    @Published var isLoadingMore: Bool = false
    @Published var hasMoreResults: Bool
    @Published private(set) var hasMoreVinted: Bool = false
    @Published var showStickyHeader: Bool = false
    @Published private(set) var initialResponseTimeMs: Int?

    @Published private(set) var currentPage: Int
    @Published private(set) var autoPrefetchPhaseFinished: Bool = false

    private var nextPageToFetch: Int
    private let paginationSearchText: String
    private var vintedPagination: VintedPaginationDTO?
    private let apiClient: any APIClientProtocol
    private var didRunBootstrap: Bool = false
    private let awaitsRailwayHydration: Bool

    private var activeSlowPollSessionId: String?
    @Published private(set) var slowProvidersInProgress: Bool = false

    /// Palette dominante image analysée (RGB 0…1). Vide en recherche texte ou avant extraction async.
    private var referencePalette: [SIMD3<Float>] = []
    private let isImageAnalysisSession: Bool

    private var colorWorkPending: [MarketplaceListing] = []
    private var colorWorkerTask: Task<Void, Never>?
    private var scoringInflight: Set<String> = []
    private var rerankDebounceTask: Task<Void, Never>?

    private var autoPrefetchTask: Task<Void, Never>?
    private var lastScrollTriggeredAt: Date = .distantPast

    private let maxResultsCap = 500

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
        isInitialSearchPending
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
        self.isImageAnalysisSession = session.mode == .imageAnalysis
        self.allListings = Self.sortSmart(session.listings)
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
            self.hasMoreResults = p.hasMore && session.listings.count < maxResultsCap
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
            let more = !q.isEmpty && n > 0 && n < maxResultsCap
            self.hasMoreResults = more
            self.hasMoreVinted = more
            self.state = .loaded(session)
        }

        applyDisplayedListingsRespectingFilter()
        startReferencePaletteExtractionIfNeeded(from: session)
        scheduleAutoPrefetchIfAppropriate()
        requestColorScoring(for: allListings, reason: "init")
    }

    /// `visibleBottom` = offset scroll + hauteur viewport ; `contentHeight` = hauteur totale du contenu scrollable.
    func reportScrollProgress(visibleBottom: CGFloat, contentHeight: CGFloat, viewportHeight: CGFloat) {
        guard autoPrefetchPhaseFinished else { return }
        guard contentHeight > viewportHeight * 1.08 else { return }
        guard hasMoreResults, !isLoadingMore else { return }
        guard allListings.count < maxResultsCap else { return }
        let depth = Double(visibleBottom / max(contentHeight, 1))
        guard depth > 0.5 else { return }
        let now = Date()
        guard now.timeIntervalSince(lastScrollTriggeredAt) > 0.55 else { return }
        lastScrollTriggeredAt = now
        #if DEBUG
        print(
            "[PAGINATION_TRIGGER] depth=\(String(format: "%.2f", depth)) visibleBottom=\(Int(visibleBottom)) content=\(Int(contentHeight)) all=\(allListings.count)"
        )
        #endif
        Task { await loadScrollExpansionBatch() }
    }

    func mergeHydratedBackendResults(_ session: SearchSession) {
        guard case .loaded(let current) = state, current.id == session.id else { return }
        guard current.hydratingBackendResults else { return }

        allListings = Self.sortSmart(session.listings)
        vintedPagination = session.vintedPagination
        initialResponseTimeMs = session.initialResponseTimeMs

        if let p = session.vintedPagination {
            currentPage = max(1, p.nextPage - 1)
            nextPageToFetch = p.nextPage
            hasMoreVinted = p.hasMore
            hasMoreResults = p.hasMore && allListings.count < maxResultsCap
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
            let more = !q.isEmpty && !session.listings.isEmpty && session.listings.count < maxResultsCap
            hasMoreResults = more
            hasMoreVinted = more
            needsInitialListingsBootstrap = false
            state = .loaded(session)
            isLoadingMore = false
        }

        slowProvidersInProgress = false
        applyDisplayedListingsRespectingFilter()
        requestColorScoring(for: allListings, reason: "hydrate")
        scheduleAutoPrefetchIfAppropriate()
    }

    func mergeSlowPoll(_ response: AnalyzeSearchResponse, httpPollStatus: String?) {
        guard case .loaded(var session) = state else { return }
        let merged = response.listings.map { MarketplaceListing.from($0) }
        allListings = Self.sortSmart(merged)
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
            hasMoreResults = p.hasMore && allListings.count < maxResultsCap
        }
        state = .loaded(session)
        applyDisplayedListingsRespectingFilter()
        requestColorScoring(for: allListings, reason: "slowPoll")
        scheduleAutoPrefetchIfAppropriate()
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
            allListings = Self.sortSmart(newItems)
            applyDisplayedListingsRespectingFilter()
            currentPage = response.page
            nextPageToFetch = 2
            hasMoreResults = response.hasMore && allListings.count < maxResultsCap
            hasMoreVinted = response.hasMore
            #if DEBUG
            print("[RESULTS_BATCH] bootstrap page=1 count=\(allListings.count) hasMore=\(response.hasMore)")
            #endif
            requestColorScoring(for: allListings, reason: "bootstrap")
            scheduleAutoPrefetchIfAppropriate()
        } catch {
            hasMoreResults = false
            hasMoreVinted = false
        }
    }

    func updateHeroVisibility(minY: CGFloat) {
        showStickyHeader = minY < -36
    }

    var availableMarketplaceSources: [String] {
        ["Vinted"]
    }

    var totalListingsCount: Int {
        displayedListings.count
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

    // MARK: - Palette référence (image analysée)

    private func startReferencePaletteExtractionIfNeeded(from session: SearchSession) {
        guard isImageAnalysisSession else { return }
        Task {
            let palette: [SIMD3<Float>] = await Task.detached(priority: .userInitiated) {
                guard let img = session.sourceImage else { return [SIMD3<Float>]() }
                return ColorAnalysisService.extractDominantColors(from: img, maxColors: 3)
            }.value
            await MainActor.run {
                self.referencePalette = palette
                #if DEBUG
                print("[COLOR_MATCH] reference ready buckets=\(palette.count)")
                #endif
                self.requestColorScoring(for: self.allListings, reason: "referenceReady")
            }
        }
    }

    // MARK: - Préfetch automatique 25 → 100

    private func scheduleAutoPrefetchIfAppropriate() {
        guard case .loaded = state else { return }
        guard !isInitialSearchPending else { return }
        guard !paginationSearchText.isEmpty else { return }
        autoPrefetchTask?.cancel()
        autoPrefetchTask = Task { await runAutoPrefetchPhase() }
    }

    private func runAutoPrefetchPhase() async {
        if Task.isCancelled { return }
        guard !autoPrefetchPhaseFinished else { return }
        guard case .loaded = state else { return }
        guard !isInitialSearchPending else { return }
        guard hasMoreResults, allListings.count < maxResultsCap else {
            autoPrefetchPhaseFinished = true
            #if DEBUG
            print("[RESULTS_BATCH] autoPrefetch skip (no more or cap)")
            #endif
            return
        }
        guard allListings.count < 100 else {
            autoPrefetchPhaseFinished = true
            #if DEBUG
            print("[RESULTS_BATCH] autoPrefetch already >=100")
            #endif
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        while !Task.isCancelled,
              allListings.count < 100,
              hasMoreResults,
              allListings.count < maxResultsCap
        {
            let before = allListings.count
            let ok = await fetchAndMergeSinglePage(context: "autoPrefetch")
            let added = allListings.count - before
            #if DEBUG
            print("[RESULTS_APPEND] autoPrefetch added=\(added) total=\(allListings.count)")
            #endif
            if !ok { break }
        }
        autoPrefetchPhaseFinished = true
        #if DEBUG
        print("[RESULTS_BATCH] autoPrefetchPhaseFinished total=\(allListings.count)")
        #endif
    }

    // MARK: - Scroll : +50 résultats (~2 pages)

    private func loadScrollExpansionBatch() async {
        guard autoPrefetchPhaseFinished else { return }
        guard !isLoadingMore, hasMoreResults else { return }
        guard allListings.count < maxResultsCap else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let start = allListings.count
        var rounds = 0
        while allListings.count - start < 50,
              hasMoreResults,
              allListings.count < maxResultsCap,
              rounds < 6
        {
            let before = allListings.count
            let ok = await fetchAndMergeSinglePage(context: "scroll50")
            rounds += 1
            #if DEBUG
            print(
                "[RESULTS_APPEND] scroll chunk added=\(allListings.count - before) total=\(allListings.count)"
            )
            #endif
            if !ok { break }
        }
        #if DEBUG
        print(
            "[PAGINATION_TRIGGER] scrollBatch done start=\(start) end=\(allListings.count) rounds=\(rounds)"
        )
        #endif
    }

    /// - Returns: `true` si une page a été fusionnée (même vide côté API), `false` si erreur réseau / arrêt.
    private func fetchAndMergeSinglePage(context: String) async -> Bool {
        guard !paginationSearchText.isEmpty else { return false }
        guard hasMoreResults else { return false }
        guard allListings.count < maxResultsCap else {
            hasMoreResults = false
            return false
        }
        #if DEBUG
        print(
            "[VINTED_OFFSET] context=\(context) page=\(nextPageToFetch) mergedBefore=\(allListings.count)"
        )
        #endif
        do {
            let response = try await apiClient.fetchVintedListingsPage(
                searchText: paginationSearchText,
                page: nextPageToFetch
            )
            let newItems = response.listings.map { MarketplaceListing.from($0) }
            let merged = Self.mergeUniquePreservingScores(existing: allListings, new: newItems)
            allListings = Self.sortSmart(merged)
            currentPage = response.page
            nextPageToFetch += 1
            let capped = allListings.count >= maxResultsCap
            hasMoreResults = response.hasMore && !capped
            hasMoreVinted = hasMoreResults
            #if DEBUG
            print(
                "[RESULTS_BATCH] ctx=\(context) page=\(response.page) batch=\(newItems.count) merged=\(allListings.count) hasMore=\(response.hasMore)"
            )
            #endif
            requestColorScoring(for: newItems, reason: context)
            applyDisplayedListingsRespectingFilter()
            return true
        } catch {
            hasMoreResults = false
            hasMoreVinted = false
            return false
        }
    }

    // MARK: - Affichage & filtre adaptatif

    private func applyDisplayedListingsRespectingFilter() {
        let sorted = Self.sortSmart(allListings)
        allListings = sorted
        displayedListings = Self.adaptiveFiltered(sorted)
        syncLoadedSessionListings()
        #if DEBUG
        print(
            "[VISIBLE_RESULTS] shown=\(displayedListings.count) raw=\(allListings.count) hasMore=\(hasMoreResults)"
        )
        #endif
    }

    private func syncLoadedSessionListings() {
        guard case .loaded(var session) = state else { return }
        session.listings = allListings
        state = .loaded(session)
    }

    private func scheduleRerankAfterScoreDelta() {
        rerankDebounceTask?.cancel()
        rerankDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                applyDisplayedListingsRespectingFilter()
            }
        }
    }

    // MARK: - Couleur async

    private func requestColorScoring(for listings: [MarketplaceListing], reason: String) {
        guard !listings.isEmpty else { return }
        if isImageAnalysisSession, referencePalette.isEmpty {
            #if DEBUG
            print("[COLOR_MATCH] defer scoring reason=\(reason) (no reference yet)")
            #endif
            return
        }
        for listing in listings where listing.visualSimilarityScore == nil {
            guard !scoringInflight.contains(listing.id) else { continue }
            scoringInflight.insert(listing.id)
            colorWorkPending.append(listing)
        }
        startColorWorkerIfNeeded()
    }

    private func startColorWorkerIfNeeded() {
        guard colorWorkerTask == nil else { return }
        colorWorkerTask = Task {
            while !Task.isCancelled {
                let next: MarketplaceListing? = await MainActor.run {
                    guard !colorWorkPending.isEmpty else {
                        colorWorkerTask = nil
                        return nil
                    }
                    return colorWorkPending.removeFirst()
                }
                guard let listing = next else { break }
                let refSnap = await MainActor.run { self.referencePalette }
                let thumb = listing.thumbnailURL ?? listing.imageURL
                let sig = await ColorAnalysisService.extractDominantColors(fromListingURL: thumb)
                let colorSim = Self.rawColorScore(reference: refSnap, listing: sig)
                await MainActor.run {
                    scoringInflight.remove(listing.id)
                    applyCompositeScore(for: listing.id, colorScore: colorSim)
                }
            }
        }
    }

    private func applyCompositeScore(for id: String, colorScore: Double) {
        guard let idx = allListings.firstIndex(where: { $0.id == id }) else { return }
        var l = allListings[idx]
        let composite = Self.compositeVisualScore(colorScore: colorScore, listing: l)
        l.visualSimilarityScore = composite
        allListings[idx] = l
        #if DEBUG
        print(
            "[SIMILARITY_SCORE] id=\(id.prefix(12))… color=\(String(format: "%.1f", colorScore)) composite=\(String(format: "%.1f", composite))"
        )
        #endif
        scheduleRerankAfterScoreDelta()
    }

    // MARK: - Tri & scores

    private static func rawColorScore(reference: [SIMD3<Float>], listing: [SIMD3<Float>]) -> Double {
        if reference.isEmpty {
            // Recherche texte : pas de photo analysée — neutre pour laisser la pondération texte / image jouer.
            return 78
        }
        return ColorAnalysisService.computeColorSimilarity(reference: reference, listing: listing)
    }

    private static func compositeVisualScore(colorScore: Double, listing: MarketplaceListing) -> Double {
        let rel = listing.relevanceScore ?? 72
        let rec = recencyScore(from: listing.publishedAtRelative)
        let img = imageQualityScore(listing)
        let v = 0.50 * colorScore + 0.26 * rel + 0.14 * rec + 0.10 * img
        return min(100, max(0, v))
    }

    private static func imageQualityScore(_ listing: MarketplaceListing) -> Double {
        if listing.thumbnailURL != nil, listing.imageURL != nil {
            return 95
        }
        if listing.imageURL != nil || listing.thumbnailURL != nil { return 82 }
        return 35
    }

    private static func recencyScore(from relative: String?) -> Double {
        guard let r = relative?.lowercased() else { return 55 }
        if r.contains("heure") || r.contains("minute") || r.contains("instant") || r.contains("aujourd") { return 100 }
        if r.contains("jour") { return 88 }
        if r.contains("semaine") { return 72 }
        if r.contains("mois") { return 52 }
        if r.contains("an") { return 38 }
        return 48
    }

    /// 1) similarité globale (couleur + signaux) 2) pertinence texte 3) qualité image 4) récence.
    private static func sortSmart(_ listings: [MarketplaceListing]) -> [MarketplaceListing] {
        listings.sorted { lhs, rhs in
            let lv = lhs.visualSimilarityScore ?? lhs.relevanceScore ?? 0
            let rv = rhs.visualSimilarityScore ?? rhs.relevanceScore ?? 0
            if abs(lv - rv) > 0.4 { return lv > rv }
            let lr = lhs.relevanceScore ?? 0
            let rr = rhs.relevanceScore ?? 0
            if abs(lr - rr) > 0.2 { return lr > rr }
            let li = imageQualityScore(lhs)
            let ri = imageQualityScore(rhs)
            if abs(li - ri) > 0.5 { return li > ri }
            return recencyScore(from: lhs.publishedAtRelative) > recencyScore(from: rhs.publishedAtRelative)
        }
    }

    /// Filtre seuil 80 → 60 pour garder ≥ 25 fiches visibles quand possible.
    private static func adaptiveFiltered(_ sorted: [MarketplaceListing]) -> [MarketplaceListing] {
        if sorted.count <= 25 { return sorted }
        var threshold = 80.0
        while threshold >= 60 {
            let passing = sorted.filter { listing in
                guard let s = listing.visualSimilarityScore else { return true }
                return s >= threshold
            }
            if passing.count >= 25 { return passing }
            if threshold <= 60 {
                // Pas assez de fiches au-dessus du seuil : on évite l’écran quasi vide.
                return passing.count > 0 ? passing : sorted
            }
            threshold -= 5
        }
        return sorted
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
        let img = (listing.imageURL ?? listing.thumbnailURL)?.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !img.isEmpty { return "img:\(img)" }
        return "fallback:\(src)|\(id)"
    }

    private static func mergeUniquePreservingScores(
        existing: [MarketplaceListing],
        new: [MarketplaceListing]
    ) -> [MarketplaceListing] {
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
}
