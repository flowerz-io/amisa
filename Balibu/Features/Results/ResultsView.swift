//
//  ResultsView.swift
//
//  Architecture ZStack :
//  ┌─ ZStack(alignment: .top) ──────────────────────────────────────────────┐
//  │  ScrollView                                                            │
//  │    VStack                                                              │
//  │      • padding top = safeAreaTop + 64  (espace sous les boutons)      │
//  │      • image analysée            ← scrolle normalement                │
//  │      • barre de filtres (ancre)  ← disparaît (opacity 0) si sticky    │
//  │      • nombre d'annonces                                               │
//  │      • grille résultats                                                │
//  │                                                                        │
//  │  topControlsOverlay              ← bouton retour + favori (toujours)   │
//  │  stickyFiltersOverlay            ← filtres + blur (si ancre hors vue)  │
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
    @State private var shouldShowStickyFilters = false
    @State private var scrollOffset: CGFloat   = 0

    private let listingGridColumns = [
        GridItem(.flexible(), spacing: DesignTokens.spacingM),
        GridItem(.flexible(), spacing: DesignTokens.spacingM),
    ]

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
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(session: SearchSession) -> some View {
        let analyzedUIImage = session.sourceImage
        let analyzedImage = analyzedUIImage.map(Image.init(uiImage:))
        let mainPreviewSize: CGFloat = 168
        let topImagePadding: CGFloat = 16

        GeometryReader { geo in
            let safeTop = Self.effectiveSafeTopInset(proxy: geo)
            let mainPreviewProgress = min(max(scrollOffset / 120, 0), 1)

            ZStack(alignment: .top) {

                // ── Fond ───────────────────────────────────────────────────
                DesignTokens.background.ignoresSafeArea()

                // ── Contenu scrollable ─────────────────────────────────────
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Color.clear
                            .frame(height: 0)
                            .background(scrollOffsetAnchor)

                        // 1. Preview principale premium dans squircle fixe
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
                        } else if session.isTextOnlySearch {
                            textQueryHero(session: session)
                                .padding(.horizontal, DesignTokens.spacingM)
                        }

                        // 2. Barre de filtres + ancre de détection sticky
                        //    Garde sa hauteur quand sticky pour éviter les sauts.
                        ResultsFiltersBar(onSelectTab: openFilterSheet)
                            .opacity(shouldShowStickyFilters ? 0 : 1)
                            .background(filterBarAnchor)

                        // 3. Compteur d'annonces
                        annoncesCountRow(session: session)
                            .padding(.horizontal, DesignTokens.spacingM)

                        // 4. Spinner initial (liste vide + chargement)
                        if viewModel.displayedListings.isEmpty, viewModel.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignTokens.spacingXL)
                                .padding(.horizontal, DesignTokens.spacingM)
                        }

                        // 5. Grille de résultats
                        LazyVGrid(columns: listingGridColumns, spacing: DesignTokens.spacingM) {
                            ForEach(viewModel.displayedListings) { listing in
                                ListingCardView(listing: listing)
                                    .onAppear {
                                        viewModel.loadMoreIfNeeded(currentItem: listing)
                                    }
                            }
                        }
                        .padding(.horizontal, DesignTokens.spacingM)

                        // 6. Spinner de pagination
                        if viewModel.isLoadingMore, !viewModel.displayedListings.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignTokens.spacingM)
                                .padding(.horizontal, DesignTokens.spacingM)
                        }
                    }
                    // Espace sous les boutons en haut (pas de spacer artificiel)
                    .padding(.top, safeTop + topImagePadding)
                    .padding(.bottom, 120)
                }
                .coordinateSpace(name: "resultsScroll")
                .onPreferenceChange(ResultsScrollOffsetKey.self) { minY in
                    scrollOffset = max(0, -minY)
                }
                // Déclenche le sticky quand l'ancre sort du champ visible
                .onPreferenceChange(FilterBarMinYPreferenceKey.self) { minY in
                    let threshold = safeTop + 60
                    withAnimation(.easeInOut(duration: 0.18)) {
                        shouldShowStickyFilters = minY <= threshold && scrollOffset > 20
                    }
                }

                // ── Header flottant (retour + mini preview + favori) ───────
                ResultsFloatingHeader(
                    safeTop: safeTop,
                    scrollOffset: scrollOffset,
                    isFavorite: isFavorite,
                    image: analyzedUIImage,
                    onBack: { dismiss() },
                    onFavoriteTap: { toggleFavorite() },
                    onPreviewTap: analyzedImage != nil ? { showImageFullscreen = true } : nil
                )
                    .zIndex(1000)

                // ── Barre de filtres sticky (blur) ─────────────────────────
                if shouldShowStickyFilters {
                    stickyFiltersOverlay(safeTop: safeTop)
                        .zIndex(20)
                        .transition(.opacity)
                }
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

    // MARK: - Ancre filter bar

    /// GeometryReader en background qui reporte le minY global de l'ancre.
    private var filterBarAnchor: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: FilterBarMinYPreferenceKey.self,
                value: proxy.frame(in: .global).minY
            )
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

    // MARK: - Hero texte (recherche par mot-clé)

    private func textQueryHero(session: SearchSession) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            Label {
                Text(session.searchQuery)
                    .font(DesignTokens.headline)
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } icon: {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(Color.secondary)
            }
            Text(String(localized: "Recherche texte sur Vinted"))
                .font(DesignTokens.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(DesignTokens.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
    }

    // MARK: - Sticky filters overlay (filtres + blur quand sticky)

    private func stickyFiltersOverlay(safeTop: CGFloat) -> some View {
        let controlsBottom = safeTop + 12 + 48

        return VStack(spacing: 0) {
            Color.clear
                .frame(height: controlsBottom)
                .allowsHitTesting(false)

            ResultsFiltersBar(onSelectTab: openFilterSheet)
                .padding(.horizontal, 0)
                .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black,               location: 0.00),
                            .init(color: .black,               location: 0.55),
                            .init(color: .black.opacity(0.25), location: 0.85),
                            .init(color: .clear,               location: 1.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        )
        .opacity(shouldShowStickyFilters ? 1 : 0)
        .allowsHitTesting(shouldShowStickyFilters)
    }

    /// `GeometryReader` sous `.ignoresSafeArea(edges: .top)` peut exposer `safeAreaInsets.top == 0` :
    /// on prend le max avec la fenêtre pour aligner sous la status bar / Dynamic Island.
    private static func effectiveSafeTopInset(proxy: GeometryProxy) -> CGFloat {
        let fromProxy = proxy.safeAreaInsets.top
        let fromWindow = windowSafeAreaTopInset()
        return max(fromProxy, fromWindow)
    }

    private static func windowSafeAreaTopInset() -> CGFloat {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return 59
        }
        let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        let top = window?.safeAreaInsets.top ?? 0
        return top > 0 ? top : 59
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
