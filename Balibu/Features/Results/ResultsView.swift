//
//  ResultsView.swift
//
//  Liste résultats : hero, barre filtres, grille ; bannières sticky au scroll.
//

import SwiftUI

struct ResultsView: View {
    @StateObject private var viewModel: ResultsViewModel

    @State private var showDetailsSheet = false
    @State private var showFilterSheet = false
    @State private var showSizeSheet = false
    @State private var showBrandSheet = false
    @State private var showConditionSheet = false
    @State private var showColorSheet = false

    private let listingGridColumns = [
        GridItem(.flexible(), spacing: DesignTokens.spacingM),
        GridItem(.flexible(), spacing: DesignTokens.spacingM),
    ]

    init(session: SearchSession) {
        _viewModel = StateObject(wrappedValue: ResultsViewModel(session: session))
    }

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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(uiColor: .secondarySystemGroupedBackground), for: .navigationBar)
        .toolbar(viewModel.showStickyHeader ? .hidden : .automatic, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !viewModel.showStickyHeader {
                    Button {
                        showDetailsSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.primary)
                    }
                    .accessibilityLabel(String(localized: "Détails de l’analyse"))
                }
            }
        }
    }

    @ViewBuilder
    private func loadedContent(session: SearchSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
                heroImage(session: session)

                if !viewModel.showStickyHeader {
                    ResultsFiltersBar(
                        showFilterSheet: $showFilterSheet,
                        showSizeSheet: $showSizeSheet,
                        showBrandSheet: $showBrandSheet,
                        showConditionSheet: $showConditionSheet,
                        showColorSheet: $showColorSheet
                    )
                }

                VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                    Text(
                        String(
                            format: String(localized: "%lld annonces"),
                            Int64(viewModel.displayedListings.count)
                        )
                    )
                    .font(DesignTokens.headline)
                    .foregroundStyle(Color.primary)

                    if session.vintedSearchFailed {
                        Text(String(localized: "Le catalogue Vinted n’a pas pu être chargé pour cette recherche. Tu peux réessayer plus tard."))
                            .font(DesignTokens.caption)
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                LazyVGrid(columns: listingGridColumns, spacing: DesignTokens.spacingM) {
                    ForEach(viewModel.displayedListings) { listing in
                        ListingCardView(listing: listing)
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentItem: listing)
                            }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.spacingM)
                }
            }
            .padding(.horizontal, DesignTokens.spacingM)
            .padding(.bottom, DesignTokens.spacingS)
        }
        .coordinateSpace(name: "resultsScroll")
        .background(DesignTokens.background)
        .onPreferenceChange(HeroVisibilityPreferenceKey.self) { minY in
            viewModel.updateHeroVisibility(minY: minY)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.showStickyHeader {
                stickyHeaderStack(session: session)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showStickyHeader)
        .sheet(isPresented: $showDetailsSheet) {
            ResultsDetailsSheet(session: session)
        }
        .sheet(isPresented: $showFilterSheet) {
            filterPlaceholderSheet(
                title: String(localized: "Filtrer"),
                message: String(localized: "Filtres avancés — à brancher."),
                isPresented: $showFilterSheet
            )
        }
        .sheet(isPresented: $showSizeSheet) {
            filterPlaceholderSheet(
                title: String(localized: "Taille"),
                message: String(localized: "Sélection des tailles — à brancher."),
                isPresented: $showSizeSheet
            )
        }
        .sheet(isPresented: $showBrandSheet) {
            filterPlaceholderSheet(
                title: String(localized: "Marque"),
                message: String(localized: "Filtrer par marque — à brancher."),
                isPresented: $showBrandSheet
            )
        }
        .sheet(isPresented: $showConditionSheet) {
            filterPlaceholderSheet(
                title: String(localized: "État"),
                message: String(localized: "Multi-sélection état — à brancher."),
                isPresented: $showConditionSheet
            )
        }
        .sheet(isPresented: $showColorSheet) {
            filterPlaceholderSheet(
                title: String(localized: "Couleur"),
                message: String(localized: "Filtrer par couleur — à brancher."),
                isPresented: $showColorSheet
            )
        }
    }

    private func heroImage(session: SearchSession) -> some View {
        Group {
            if let image = session.sourceImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: HeroVisibilityPreferenceKey.self,
                                value: geo.frame(in: .named("resultsScroll")).minY
                            )
                        }
                    )
            }
        }
    }

    private func stickyHeaderStack(session: SearchSession) -> some View {
        VStack(spacing: 0) {
            ResultsStickyBar(
                thumbnail: session.sourceImage,
                onInfoTap: { showDetailsSheet = true }
            )
            ResultsFiltersBar(
                showFilterSheet: $showFilterSheet,
                showSizeSheet: $showSizeSheet,
                showBrandSheet: $showBrandSheet,
                showConditionSheet: $showConditionSheet,
                showColorSheet: $showColorSheet
            )
            .padding(.horizontal, DesignTokens.spacingS)
            .padding(.bottom, DesignTokens.spacingXS)
        }
        .background {
            Rectangle()
                .fill(.thinMaterial)
                .ignoresSafeArea(edges: .top)
        }
    }

    private func filterPlaceholderSheet(title: String, message: String, isPresented: Binding<Bool>) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
                Text(message)
                    .font(DesignTokens.body)
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            .padding(DesignTokens.spacingM)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DesignTokens.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Fermer")) {
                        isPresented.wrappedValue = false
                    }
                }
            }
        }
    }

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

#Preview {
    NavigationStack {
        ResultsView(session: .mock)
    }
}
