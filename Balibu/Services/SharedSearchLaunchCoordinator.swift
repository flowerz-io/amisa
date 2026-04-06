//
//  SharedSearchLaunchCoordinator.swift
//  Balibu
//
//  Au lancement / foreground : lit l’App Group et route vers résultats, chargement ou erreur
//  selon la source de vérité Railway.
//

import Foundation
import SwiftUI

@MainActor
enum SharedSearchLaunchCoordinator {
    static func resumeIfNeeded(router: Router, apiClient: APIClientProtocol) async {
        guard router.path.isEmpty else { return }
        guard let pending = SharedSearchSessionStore.shared.peekPending() else { return }

        router.selectedTab = .search

        do {
            let remote = try await apiClient.fetchSearchSessionStatus(sessionId: pending.sessionId)
            SharedSearchSessionStore.shared.updateStatus(remote.status, searchQuery: remote.searchQuery)

            switch remote.status {
            case "completed":
                if let resp = remote.response {
                    let session = SearchSessionFromRemote.buildSession(
                        response: resp,
                        imageFileName: pending.originalImagePath
                    )
                    router.navigateToResultsFromSharedSession(session: session)
                    return
                }
                if let jsonName = pending.completedResultJSONFileName,
                   let url = SharedSearchSessionStore.sessionResultJSONURL(fileName: jsonName),
                   let data = try? Data(contentsOf: url),
                   let resp = try? SearchSessionFromRemote.decodeAnalyzeResponse(data: data) {
                    let session = SearchSessionFromRemote.buildSession(
                        response: resp,
                        imageFileName: pending.originalImagePath
                    )
                    router.navigateToResultsFromSharedSession(session: session)
                    return
                }
                router.navigateToRemoteSessionLoading(sessionId: pending.sessionId)

            case "failed":
                let msg = remote.error?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                    ?? String(localized: "La recherche n’a pas pu aboutir.")
                router.navigateToSessionResumeFailed(message: msg)

            case "queued", "analyzing", "searching":
                router.navigateToRemoteSessionLoading(sessionId: pending.sessionId)

            default:
                router.navigateToRemoteSessionLoading(sessionId: pending.sessionId)
            }
        } catch {
            router.navigateToRemoteSessionLoading(sessionId: pending.sessionId)
        }
    }

    /// Depuis une notification qui transporte un `sessionId` (pivot de navigation).
    static func openSessionFromNotification(sessionId: String, router: Router, apiClient: APIClientProtocol) async {
        router.selectedTab = .search
        router.path = NavigationPath()
        do {
            let remote = try await apiClient.fetchSearchSessionStatus(sessionId: sessionId)
            switch remote.status {
            case "completed":
                if let resp = remote.response {
                    let session = SearchSessionFromRemote.buildSession(response: resp, imageFileName: nil)
                    router.navigateToResultsFromSharedSession(session: session)
                    return
                }
                router.navigateToRemoteSessionLoading(sessionId: sessionId)
            case "failed":
                let msg = remote.error?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                    ?? String(localized: "La recherche n’a pas pu aboutir.")
                router.navigateToSessionResumeFailed(message: msg)
            default:
                router.navigateToRemoteSessionLoading(sessionId: sessionId)
            }
        } catch {
            router.navigateToRemoteSessionLoading(sessionId: sessionId)
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
