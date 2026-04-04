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
            Group {
                switch viewModel.searchState {
                case .idle:
                    ProgressView()
                case .loading:
                    VStack(spacing: DesignTokens.spacingM) {
                        ProgressView()
                        Text(String(localized: "Analyse en cours…"))
                            .font(DesignTokens.body)
                            .foregroundStyle(Color.secondary)
                    }
                case .error(let message):
                    VStack(spacing: DesignTokens.spacingM) {
                        Text(message)
                            .font(DesignTokens.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal)
                        Button(String(localized: "Fermer")) {
                            router.popToRoot()
                        }
                        .buttonStyle(.bordered)
                    }
                case .success:
                    Color.clear
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task(id: payload.id) {
            viewModel.setSearchHistoryService(.shared)
            viewModel.startAnalysisFromPreparedFile { session in
                router.replaceShareImportWithResults(session: session)
                ShareStorageService.shared.markPendingShareImportConsumed(id: payload.id)
                NotificationManager.shared.cancelShareResultsNotification(importId: payload.id)
            }
        }
    }
}
