//
//  RemoteSessionLoadingView.swift
//  Balibu
//
//  Polling GET /search-sessions/:id — affiche les résultats (ou skeleton) comme la Share Extension, sans écran de chargement isolé.
//

import SwiftUI

struct RemoteSessionLoadingView: View {
    let sessionId: String
    var continuitySeed: SearchSession?

    @EnvironmentObject private var router: Router

    @State private var didFail = false
    @State private var failureMessage: String = ""

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        Group {
            if didFail {
                ContentUnavailableView(
                    String(localized: "Recherche interrompue"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(failureMessage)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let seed = continuitySeed {
                ResultsView(session: seed)
            } else {
                ZStack {
                    DesignTokens.background.ignoresSafeArea()
                    ScrollView {
                        ResultsListingSkeletonGrid(columns: columns, rowSpacing: 14)
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .task(id: sessionId) {
            await pollLoop()
        }
    }

    private func pendingImageFileName() -> String? {
        guard let p = SharedSearchSessionStore.shared.peekPending(), p.sessionId == sessionId else { return nil }
        return p.originalImagePath
    }

    private func pollLoop() async {
        let api = APIConfig.apiClient
        let maxIterations = 80
        for _ in 0..<maxIterations {
            do {
                let remote = try await SearchSessionStatusService.fetchStatus(sessionId: sessionId, apiClient: api)
                await MainActor.run {
                    SharedSearchSessionStore.shared.updateStatus(remote.status, searchQuery: remote.searchQuery)
                }

                switch remote.status {
                case "completed":
                    if let resp = remote.response {
                        let session = SearchSessionFromRemote.buildSession(
                            response: resp,
                            imageFileName: pendingImageFileName()
                        )
                        await MainActor.run {
                            router.navigateToResultsFromSharedSession(session: session)
                        }
                        return
                    }
                    if let pending = SharedSearchSessionStore.shared.peekPending(),
                       pending.sessionId == sessionId,
                       let jsonName = pending.completedResultJSONFileName,
                       let url = SharedSearchSessionStore.sessionResultJSONURL(fileName: jsonName),
                       let data = try? Data(contentsOf: url),
                       let resp = try? SearchSessionFromRemote.decodeAnalyzeResponse(data: data) {
                        let session = SearchSessionFromRemote.buildSession(
                            response: resp,
                            imageFileName: pendingImageFileName()
                        )
                        await MainActor.run {
                            router.navigateToResultsFromSharedSession(session: session)
                        }
                        return
                    }
                    await MainActor.run {
                        didFail = true
                        failureMessage = String(localized: "Réponse incomplète du serveur.")
                    }
                    return

                case "failed":
                    let trimmed = (remote.error ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let msg = trimmed.isEmpty ? String(localized: "La recherche n’a pas pu aboutir.") : trimmed
                    await MainActor.run {
                        router.navigateToSessionResumeFailed(message: msg)
                    }
                    return

                default:
                    break
                }
            } catch {
                if let apiError = error as? APIError, case .sessionNotFound = apiError {
                    await MainActor.run {
                        SharedSearchSessionStore.shared.clear()
                        didFail = true
                        failureMessage = apiError.localizedDescription
                    }
                    return
                }
            }

            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { return }
        }

        await MainActor.run {
            didFail = true
            failureMessage = String(localized: "Délai dépassé. Rouvre Amisa plus tard ou réessaie depuis le partage.")
        }
    }
}
