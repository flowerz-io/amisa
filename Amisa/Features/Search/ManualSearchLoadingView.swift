//
//  ManualSearchLoadingView.swift
//  Chargement court puis Results (skeletons pendant la fin du fetch).
//

import SwiftUI

struct ManualSearchLoadingView: View {
    let query: String

    @EnvironmentObject private var router: Router
    @StateObject private var viewModel = HomeViewModel(searchHistoryService: .shared)
    @State private var errorMessage: String?

    var body: some View {
        LoadingSearchView(
            textQuery: query,
            message: String(localized: "Recherche des annonces Vinted similaires…")
        )
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            router.isTabBarHidden = true
        }
        .onDisappear {
            router.isTabBarHidden = false
        }
        .task(id: query) {
            await performSearch()
        }
        .alert(String(localized: "Recherche"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(String(localized: "OK"), role: .cancel) {
                errorMessage = nil
                router.dismissCurrentRoute()
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func performSearch() async {
        let presetId = UUID()
        let coordinator = AnalyzeFetchCoordinator()

        let fetchTask = Task {
            await coordinator.run {
                try await viewModel.submitTextSearch(query: query, presetSessionId: presetId)
            }
        }

        try? await Task.sleep(nanoseconds: FullscreenSearchTiming.textNanoseconds)

        let outcome = await coordinator.peekOutcome()

        switch outcome {
        case .success(let session):
            await MainActor.run {
                router.completeManualSearchLoading(with: session)
            }
            await fetchTask.value

        case .failure(let error):
            fetchTask.cancel()
            await MainActor.run {
                errorMessage = error.localizedDescription
            }

        case nil:
            let placeholder = SearchSession(
                id: presetId,
                imageFileName: nil,
                thumbnailImageURL: nil,
                searchQuery: query,
                generatedQueries: [query],
                attributes: nil,
                listings: [],
                createdAt: Date(),
                mode: .textQuery,
                previewImageURLs: [],
                hydratingBackendResults: true
            )
            await MainActor.run {
                router.completeManualSearchLoading(with: placeholder)
            }

            Task {
                await fetchTask.value
                let final = await coordinator.peekOutcome()
                await MainActor.run {
                    switch final {
                    case .success(let s):
                        NotificationCenter.default.post(name: .amisaSearchSessionHydrated, object: s)
                    case .failure(let err):
                        NotificationCenter.default.post(
                            name: .amisaSearchHydrationFailed,
                            object: err.localizedDescription
                        )
                    case nil:
                        break
                    }
                }
            }
        }
    }
}
