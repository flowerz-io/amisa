//
//  ResultsView.swift
//
//  Architecture ZStack :
//  ┌─ ZStack(alignment: .top) ──────────────────────────────────────────────┐
//  │  ScrollView                                                            │
//  │    … hero image, filtres (ancre), grille …                             │
//  │  ResultsFloatingHeader (gradient + pilule + filtres sticky)            │
//  │  ResultsHeaderButtonsOverlay (retour / favori fixes, zIndex max)       │
//  └────────────────────────────────────────────────────────────────────────┘
//

import SwiftUI
import UIKit

struct ResultsView: View {
    @StateObject private var viewModel: ResultsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDetailsSheet        = false
    @State private var showImageFullscreen     = false
    @State private var showFiltersSheet        = false
    @State private var selectedFilterTab: ResultsFilterTab = .marketplace
    @State private var isFavorite              = false
    @State private var scrollOffset: CGFloat   = 0
    @State private var analyzedHeroMinY: CGFloat = .greatestFiniteMagnitude
    @State private var resultsFilterBarMinY: CGFloat = .greatestFiniteMagnitude

    private let gridHorizontalPadding: CGFloat = 16
    private let gridColumnSpacing: CGFloat = 12
    private let gridRowSpacing: CGFloat = 14
    /// Espace sous la rangée retour / requête / favori pour que la barre de filtres ne passe pas sous le chrome flottant (recherche texte sans hero scroll).
    private let manualSearchScrollTopInset: CGFloat = 48

    private var listingGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridColumnSpacing),
            GridItem(.flexible(), spacing: gridColumnSpacing),
        ]
    }

    init(session: SearchSession) {
        _viewModel = StateObject(wrappedValue: ResultsViewModel(session: session))
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch viewModel.state {
            case .loaded(let session):
                loadedContent(session: session)
            case .error(let message):
                errorState(message: message)
            case .empty:
                emptyState()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(NotificationCenter.default.publisher(for: .amisaSearchSessionHydrated)) { note in
            guard let session = note.object as? SearchSession else { return }
            viewModel.mergeHydratedBackendResults(session)
        }
        .onReceive(NotificationCenter.default.publisher(for: .amisaSearchHydrationFailed)) { note in
            let msg = (note.object as? String) ?? String(localized: "La recherche n’a pas abouti.")
            viewModel.applyHydrationFailure(message: msg)
        }
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(session: SearchSession) -> some View {
        let analyzedUIImage = session.sourceImage
        let analyzedImage = analyzedUIImage.map(Image.init(uiImage:))
        let mainPreviewSize: CGFloat = 168
        let topImagePadding: CGFloat = 16

        GeometryReader { geo in
            let safeTop = EffectiveSafeArea.topInset(proxy: geo)
            let mainPreviewProgress = min(max(scrollOffset / 120, 0), 1)

            let showCompactChrome = analyzedUIImage != nil && analyzedHeroMinY < safeTop + 24
            let showFloatingStickyFilters =
                showCompactChrome || (analyzedUIImage == nil && resultsFilterBarMinY <= safeTop + 6)

            let headerContent: ResultsHeaderContent = {
                if let img = analyzedUIImage {
                    return .analyzedImage(img)
                }
                if session.isTextOnlySearch {
                    return .manualQuery(session.searchQuery)
                }
                return .analyzedImage(nil)
            }()

            let showCompactCenter: Bool = {
                switch headerContent {
                case .analyzedImage:
                    return showCompactChrome
                case .manualQuery:
                    return showFloatingStickyFilters
                }
            }()

            ZStack(alignment: .top) {

                // ── Fond ───────────────────────────────────────────────────
                DesignTokens.background.ignoresSafeArea()

                // ── Contenu scrollable ─────────────────────────────────────
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Color.clear
                            .frame(height: 0)
                            .background(scrollOffsetAnchor)

                        if session.isTextOnlySearch {
                            Color.clear
                                .frame(height: manualSearchScrollTopInset)
                        }

                        // 1. Preview principale premium dans squircle fixe (analyse image uniquement)
                        if let analyzedImage {
                            HStack {
                                Spacer(minLength: 0)
                                AnalysisPreviewSquircle(image: analyzedImage, size: mainPreviewSize)
                                    .opacity(1 - mainPreviewProgress)
                                    .scaleEffect(1 - mainPreviewProgress * 0.08)
                                    .animation(.easeInOut(duration: 0.18), value: mainPreviewProgress)
                                    .contentShape(Rectangle())
                                    .onTapGesture { showImageFullscreen = true }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, DesignTokens.spacingM)
                            .analyzedHeroGlobalMinYAnchor()
                        }

                        // 2. Barre de filtres + ancre
                        ResultsFiltersBar(onSelectTab: openFilterSheet)
                            .opacity(showFloatingStickyFilters ? 0 : 1)
                            .allowsHitTesting(!showFloatingStickyFilters)
                            .filterBarGlobalMinYAnchor()

                        // 3. Compteur d'annonces
                        annoncesCountRow(session: session)
                            .padding(.horizontal, DesignTokens.spacingM)

                        // 4. Skeleton initial (liste vide + chargement — même langage visuel que la Share Extension)
                        if viewModel.displayedListings.isEmpty, viewModel.isLoadingMore {
                            ResultsListingSkeletonGrid(columns: listingGridColumns, rowSpacing: gridRowSpacing)
                                .padding(.horizontal, gridHorizontalPadding)
                                .padding(.vertical, DesignTokens.spacingS)
                        }

                        // 5. Grille de résultats
                        LazyVGrid(columns: listingGridColumns, spacing: gridRowSpacing) {
                            ForEach(viewModel.displayedListings) { listing in
                                ListingCardView(listing: listing)
                                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                                    .onAppear {
                                        viewModel.loadMoreIfNeeded(currentItem: listing)
                                    }
                            }
                        }
                        .padding(.horizontal, gridHorizontalPadding)
                        .animation(.easeOut(duration: 0.28), value: viewModel.displayedListings.count)

                        // 6. Pagination discrète
                        if viewModel.isLoadingMore, !viewModel.displayedListings.isEmpty {
                            ProgressView()
                                .controlSize(.regular)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignTokens.spacingM)
                                .padding(.horizontal, DesignTokens.spacingM)
                        }
                    }
                    .padding(.top, safeTop + topImagePadding)
                    .padding(.bottom, 120)
                }
                .coordinateSpace(name: "resultsScroll")
                .onPreferenceChange(ResultsScrollOffsetKey.self) { minY in
                    scrollOffset = max(0, -minY)
                }
                .onPreferenceChange(AnalyzedHeroMinYPreferenceKey.self) { minY in
                    analyzedHeroMinY = minY
                }
                .onPreferenceChange(FilterBarMinYPreferenceKey.self) { minY in
                    resultsFilterBarMinY = minY
                }

                ResultsFloatingHeader(
                    safeTop: safeTop,
                    headerContent: headerContent,
                    showCompactCenter: showCompactCenter,
                    shouldShowFilters: showFloatingStickyFilters,
                    onPreviewTap: analyzedUIImage != nil ? { showImageFullscreen = true } : nil,
                    onSelectFilterTab: openFilterSheet
                )
                .zIndex(9_999)

                ResultsHeaderButtonsOverlay(
                    isFavorite: isFavorite,
                    onBack: { dismiss() },
                    onFavorite: { toggleFavorite() },
                    safeTop: safeTop
                )
                .zIndex(10_000)
            }
        }
        .ignoresSafeArea(edges: .top)
        .task {
            await viewModel.bootstrapInitialListingsIfNeeded()
        }
        .onAppear {
            isFavorite = FavoriteSearchService.shared.isFavorite(id: session.id)
        }
        .fullScreenCover(isPresented: $showImageFullscreen) {
            NavigationStack {
                if let img = session.sourceImage {
                    ResultsImageFullscreenViewer(image: img, session: session)
                }
            }
        }
        .sheet(isPresented: $showDetailsSheet) {
            ResultsDetailsSheet(session: session)
        }
        .sheet(isPresented: $showFiltersSheet) {
            ResultsFiltersPagerSheet(
                selectedTab:         $selectedFilterTab,
                enabledProviderKeys: $viewModel.enabledProviderKeys,
                availableProviders:  viewModel.availableMarketplaceSources,
                providerAvailability: viewModel.providerAvailabilityMap,
                providerCounts:      viewModel.providerCounts,
                countFormatter:      viewModel.formatListingsCount,
                onClose:             { showFiltersSheet = false }
            )
            .presentationDetents([.fraction(0.52), .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.52)))
        }
    }

    // MARK: - Scroll anchor

    /// Mesure l'offset global du ScrollView pour animer le header compact.
    private var scrollOffsetAnchor: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ResultsScrollOffsetKey.self,
                value: proxy.frame(in: .named("resultsScroll")).minY
            )
        }
    }

    // MARK: - Compteur d'annonces

    private func annoncesCountRow(session: SearchSession) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(viewModel.formattedTotalListingsCount) annonces")
                    .font(DesignTokens.headline)
                    .foregroundStyle(Color.primary)

                if let t = viewModel.formattedInitialSearchTime {
                    Text("(\(t))")
                        .font(DesignTokens.caption)
                        .foregroundStyle(Color.secondary)
                }
            }

            if session.vintedSearchFailed {
                Text(String(localized: "Le catalogue Vinted n'a pas pu être chargé pour cette recherche. Tu peux réessayer plus tard."))
                    .font(DesignTokens.caption)
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Favoris / filtres

    private func toggleFavorite() {
        guard case .loaded(let session) = viewModel.state else { return }
        isFavorite = FavoriteSearchService.shared.toggle(session: session)
    }

    private func openFilterSheet(_ tab: ResultsFilterTab) {
        selectedFilterTab = tab
        showFiltersSheet = true
    }

    // MARK: - États erreur / vide

    private func errorState(message: String) -> some View {
        VStack(spacing: DesignTokens.spacingL) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.secondary)
            Text(message)
                .font(DesignTokens.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState() -> some View {
        VStack(spacing: DesignTokens.spacingL) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.secondary)
            Text(String(localized: "Aucun résultat"))
                .font(DesignTokens.headline)
                .foregroundStyle(Color.primary)
            Text(String(localized: "Essaie une autre image ou requête."))
                .font(DesignTokens.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Visionneuse image plein écran

private struct ResultsImageFullscreenViewer: View {
    let image: UIImage
    let session: SearchSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDetails = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showDetails = true } label: {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)
                }
                .accessibilityLabel(String(localized: "Détails de l'analyse"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)
                }
                .accessibilityLabel(String(localized: "Fermer"))
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(UIColor.systemBackground).opacity(0.35), for: .navigationBar)
        .sheet(isPresented: $showDetails) {
            ResultsDetailsSheet(session: session)
        }
    }
}

#Preview {
    NavigationStack {
        ResultsView(session: .mock)
    }
}
