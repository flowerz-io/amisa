//
//  RemoteSessionLoadingView.swift
//  Balibu
//
//  Chargement lié à une session Railway (polling GET /search-sessions/:id).
//

import SwiftUI

struct RemoteSessionLoadingView: View {
    let sessionId: String
    @EnvironmentObject private var router: Router

    @State private var displayedStatus: String = ""
    @State private var didFail = false
    @State private var failureMessage: String = ""

    private var previewImage: UIImage? {
        guard let p = SharedSearchSessionStore.shared.peekPending(), p.sessionId == sessionId,
              let name = p.originalImagePath else { return nil }
        return ImagePersistenceService.shared.loadUIImage(fileName: name)
    }

    private var loadingMessage: String {
        let base = String(localized: "Recherche des annonces similaires…")
        if displayedStatus.isEmpty { return base }
        return base
    }

    var body: some View {
        Group {
            if didFail {
                ContentUnavailableView(
                    String(localized: "Recherche interrompue"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(failureMessage)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LoadingSearchView(previewImage: previewImage, message: loadingMessage)
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
                    displayedStatus = remote.status
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
                // Erreur réseau : on continue à poller.
            }

            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { return }
        }

        await MainActor.run {
            didFail = true
            failureMessage = String(localized: "Délai dépassé. Rouvre Balibu plus tard ou réessaie depuis le partage.")
        }
    }
}
