import Combine
import SwiftUI

enum HomeDiscoveryFeedBuilder {
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0xDEADBEEF : seed }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    static func build(sessions: [SearchSession], favoriteIds: Set<UUID>, refreshEntropy: UInt64 = 0) -> [MarketplaceListing] {
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

        var rng = SeededGenerator(seed: UInt64(ordered.count &* 17 &+ interleaved.count) ^ refreshEntropy)
        return interleaved.shuffled(using: &rng)
    }
}

struct DiscoveryHomeView: View {
    @EnvironmentObject private var router: Router
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = DiscoveryHomeViewModel()
    /// Grille marketplace : marges réduites par rapport aux bords écran.
    private let gridHorizontalPadding: CGFloat = 16
    private let gridColumnSpacing: CGFloat = 12
    private let gridRowSpacing: CGFloat = 14
    /// Espacement homogène recherche → filtres → grille.
    private let homeSectionSpacing: CGFloat = 12
    private let homeTopInset: CGFloat = 8

    /// `contentOffset.y + adjustedContentInset.top` — négatif pendant le pull down depuis le haut.
    @State private var homeScrollY: CGFloat = 0
    @State private var isDraggingHome = false
    @State private var didPassRefreshThreshold = false
    @State private var isRefreshingHome = false
    @State private var isHomeSearchBarPinned = false
    @State private var shouldShowStickyHomeFilters = false

    @State private var homeSearchText = ""
    @FocusState private var isHomeSearchFocused: Bool
    @State private var isHomeManualSearchBusy = false

    @State private var showHomeFiltersSheet = false
    @State private var selectedHomeFilterTab: ResultsFilterTab = .marketplace
    /// Sources désactivées dans la sheet (le reste du feed reste visible).
    @State private var homeDisabledProviderKeys: Set<String> = []

    private var listingGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridColumnSpacing),
            GridItem(.flexible(), spacing: gridColumnSpacing),
        ]
    }

    private var homePullDistance: CGFloat {
        max(0, -homeScrollY)
    }

    private var displayedHomeListings: [MarketplaceListing] {
        viewModel.feedListings.filter { listing in
            let key = MarketplaceSource.canonicalKey(from: listing.source)
            return !homeDisabledProviderKeys.contains(key)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let safeTop = EffectiveSafeArea.topInset(proxy: geo)
            /// Safe area locale pour positionner le sticky sous la status bar (fallback si le proxy renvoie 0).
            let homeStickySafeTop = geo.safeAreaInsets.top > 1 ? geo.safeAreaInsets.top : safeTop
            ZStack(alignment: .top) {
                homeChromeBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: homeSectionSpacing) {
                        PullSearchAccordion(
                            pullDistance: homePullDistance,
                            isPinned: isHomeSearchBarPinned,
                            isRefreshing: isRefreshingHome,
                            horizontalPadding: gridHorizontalPadding,
                            searchText: $homeSearchText,
                            searchFocused: $isHomeSearchFocused,
                            onSubmitSearch: { launchManualSearchFromHome($0) },
                            onCameraTap: { router.openPhotoAnalysis() }
                        )

                        ResultsFiltersBar(onSelectTab: openHomeFilterSheet)
                            .opacity(shouldShowStickyHomeFilters ? 0 : 1)
                            .allowsHitTesting(!shouldShowStickyHomeFilters)
                            .filterBarGlobalMinYAnchor()

                        if viewModel.feedListings.isEmpty {
                            emptyState
                                .padding(.horizontal, gridHorizontalPadding)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if displayedHomeListings.isEmpty {
                            EmptyStateView(
                                icon: "line.3.horizontal.decrease.circle",
                                title: String(localized: "Aucune annonce"),
                                message: String(localized: "Réactive au moins une source dans Filtrer.")
                            )
                            .padding(.horizontal, gridHorizontalPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            LazyVGrid(columns: listingGridColumns, spacing: gridRowSpacing) {
                                ForEach(displayedHomeListings) { listing in
                                    ListingCardView(listing: listing)
                                }
                            }
                            .padding(.horizontal, gridHorizontalPadding)
                        }
                    }
                    .padding(.top, homeTopInset)
                    .padding(.bottom, 120)
                    .background(
                        ScrollViewOffsetReader { y, isDragging in
                            handleHomeScroll(y: y, isDragging: isDragging)
                        }
                    )
                }
                .scrollDismissesKeyboard(.interactively)
                .onPreferenceChange(FilterBarMinYPreferenceKey.self) { minY in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        shouldShowStickyHomeFilters = minY <= safeTop + 6
                    }
                }

                if shouldShowStickyHomeFilters {
                    HomeStickyFilterOverlay(
                        safeTop: homeStickySafeTop,
                        onSelectTab: openHomeFilterSheet
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.load()
            pruneHomeDisabledProvidersForFeed()
        }
        .onChange(of: router.path.count) { _, _ in
            viewModel.load()
            isHomeManualSearchBusy = false
        }
        .onChange(of: router.selectedTab) { _, new in
            if new == .home { viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .amisaSearchHistoryDidUpdate)) { _ in
            viewModel.load(forceRefresh: true)
        }
        .onChange(of: viewModel.feedListings.count) { _, _ in
            pruneHomeDisabledProvidersForFeed()
        }
        .sheet(isPresented: $showHomeFiltersSheet) {
            ResultsFiltersPagerSheet(
                selectedTab: $selectedHomeFilterTab,
                enabledProviderKeys: homeFiltersEnabledBinding,
                availableProviders: homeFilterAvailableSources,
                providerAvailability: nil,
                providerCounts: homeProviderCountsDTO(),
                countFormatter: { "\($0)" },
                onClose: { showHomeFiltersSheet = false }
            )
            .presentationDetents([.fraction(0.52), .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.52)))
        }
    }

    private var homeChromeBackground: some View {
        Group {
            if colorScheme == .dark {
                Color.black
            } else {
                Color.homeLightChrome
            }
        }
    }

    private var homeFiltersEnabledBinding: Binding<Set<String>> {
        Binding(
            get: {
                homeCanonicalKeysInFeed().subtracting(homeDisabledProviderKeys)
            },
            set: { enabled in
                let all = homeCanonicalKeysInFeed()
                homeDisabledProviderKeys = all.subtracting(enabled)
            }
        )
    }

    private func homeCanonicalKeysInFeed() -> Set<String> {
        Set(viewModel.feedListings.map { MarketplaceSource.canonicalKey(from: $0.source) })
    }

    /// Une entrée par clé canonique (libellé source du premier listing rencontré).
    private var homeFilterAvailableSources: [String] {
        let grouped = Dictionary(grouping: viewModel.feedListings, by: { MarketplaceSource.canonicalKey(from: $0.source) })
        return grouped.keys.sorted().compactMap { key in grouped[key]?.first?.source }
    }

    private func homeProviderCountsDTO() -> ProviderCountsDTO {
        var vinted = 0
        var grailed = 0
        var ebay = 0
        var leboncoin = 0
        var depop = 0
        for listing in viewModel.feedListings {
            switch MarketplaceSource.canonicalKey(from: listing.source) {
            case "vinted": vinted += 1
            case "grailed": grailed += 1
            case "ebay": ebay += 1
            case "leboncoin": leboncoin += 1
            case "depop": depop += 1
            default: break
            }
        }
        return ProviderCountsDTO(vinted: vinted, grailed: grailed, ebay: ebay, leboncoin: leboncoin, depop: depop)
    }

    private func pruneHomeDisabledProvidersForFeed() {
        let all = homeCanonicalKeysInFeed()
        homeDisabledProviderKeys = homeDisabledProviderKeys.intersection(all)
    }

    private func openHomeFilterSheet(_ tab: ResultsFilterTab) {
        selectedHomeFilterTab = tab
        showHomeFiltersSheet = true
    }

    private func handleHomeScroll(y: CGFloat, isDragging: Bool) {
        homeScrollY = y
        isDraggingHome = isDragging

        let pull = max(0, -y)

        #if DEBUG
        print("HOME_Y:", y, "PULL:", pull, "DRAG:", isDragging)
        print(
            "HOME_REFRESH_CHECK",
            "pull:", pull,
            "drag:", isDraggingHome,
            "passed:", didPassRefreshThreshold,
            "refreshing:", isRefreshingHome,
            "count:", viewModel.feedListings.count,
            "pinned:", isHomeSearchBarPinned
        )
        #endif

        if pull >= 72 {
            isHomeSearchBarPinned = true
        }

        if pull >= 125 {
            didPassRefreshThreshold = true
        }

        if didPassRefreshThreshold && !isDragging && pull < 20 && !isRefreshingHome {
            didPassRefreshThreshold = false
            Task {
                await refreshHomeLikeColdStart()
            }
        }
    }

    @MainActor
    private func refreshHomeLikeColdStart() async {
        guard !isRefreshingHome else { return }

        isRefreshingHome = true

        await viewModel.reloadFromScratch(forceRemote: true)
        DynamicTabIconStore.shared.updateIfNeeded(with: viewModel.feedListings)

        try? await Task.sleep(nanoseconds: 500_000_000)

        isRefreshingHome = false
    }

    /// Recherche texte : écran de chargement (aperçu requête) puis résultats — même animation que l’analyse image.
    private func launchManualSearchFromHome(_ query: String) {
        guard !isHomeManualSearchBusy else { return }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isHomeManualSearchBusy = true
        homeSearchText = ""
        isHomeSearchFocused = false
        router.presentManualSearchLoading(query: q)
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
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load(forceRefresh: Bool = false) {
        errorMessage = nil
        let sessions = SearchHistoryService.shared.fetchSessions()
        let favIds = Set(FavoriteSearchService.shared.allRecords().map(\.id))
        let entropy = forceRefresh ? UInt64.random(in: .min ... .max) : 0
        feedListings = HomeDiscoveryFeedBuilder.build(sessions: sessions, favoriteIds: favIds, refreshEntropy: entropy)

        DynamicTabIconStore.shared.updateIfNeeded(with: feedListings)
    }

    func reloadFromScratch(forceRemote: Bool = true) async {
        #if DEBUG
        print("HOME reloadFromScratch(forceRemote:", forceRemote, ")")
        #endif
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        feedListings.removeAll()
        await Task.yield()

        load(forceRefresh: forceRemote)
    }
}

#Preview {
    NavigationStack {
        DiscoveryHomeView()
            .environmentObject(Router())
    }
}
