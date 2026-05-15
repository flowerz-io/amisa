//
//  ShareImportProcessingView.swift
//  Balibu
//
//  Analyse automatique après import Share Extension (sans écran Review).
//

import SwiftUI

struct ShareImportProcessingView: View {
    @EnvironmentObject private var router: Router
    let payload: SharedImportPayload

    @StateObject private var viewModel: SharedImportReviewViewModel

    @State private var pipelineError: String?

    init(payload: SharedImportPayload, apiClient: (any APIClientProtocol)? = nil) {
        self.payload = payload
        _viewModel = StateObject(wrappedValue: SharedImportReviewViewModel(
            payload: payload,
            apiClient: apiClient ?? APIConfig.apiClient
        ))
    }

    var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()
            if let pipelineError {
                VStack(spacing: DesignTokens.spacingM) {
                    Text(pipelineError)
                        .font(DesignTokens.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal)
                    Button(String(localized: "Fermer")) {
                        router.popToRoot()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack {
                    Spacer(minLength: 0)
                    AnalysisLoadingView()
                        .padding(.horizontal, DesignTokens.spacingL)
                    Spacer(minLength: 0)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task(id: payload.id) {
            await runShareImportPipeline()
        }
    }

    private func runShareImportPipeline() async {
        viewModel.setSearchHistoryService(.shared)
        pipelineError = nil

        guard let ui = viewModel.preparedUIImageForShareImport else {
            await MainActor.run {
                pipelineError = String(localized: "Image introuvable dans le conteneur partagé.")
            }
            return
        }

        let presetId = UUID()
        let coordinator = AnalyzeFetchCoordinator()

        let package: (Data, String)
        do {
            package = try viewModel.preparePersistedImage(from: ui)
        } catch {
            await MainActor.run {
                pipelineError = error.localizedDescription
            }
            return
        }
        let (imageData, fileName) = package

        let fetchTask = Task {
            await coordinator.run {
                try await viewModel.fetchCompletedImageSession(imageData: imageData, presetId: presetId, savedFileName: fileName)
            }
        }

        try? await Task.sleep(nanoseconds: FullscreenSearchTiming.photoNanoseconds)

        let outcome = await coordinator.peekOutcome()

        await MainActor.run {
            switch outcome {
            case .success(let session):
                router.replaceShareImportWithResults(session: session)
                ShareStorageService.shared.markPendingShareImportConsumed(id: payload.id)
                NotificationManager.shared.cancelShareResultsNotification(importId: payload.id)

            case .failure(let error):
                pipelineError = error.localizedDescription
                fetchTask.cancel()

            case nil:
                let placeholder = viewModel.hydratingPlaceholderSession(presetId: presetId, savedFileName: fileName)
                router.replaceShareImportWithResults(session: placeholder)
                ShareStorageService.shared.markPendingShareImportConsumed(id: payload.id)
                NotificationManager.shared.cancelShareResultsNotification(importId: payload.id)

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
}
