//
//  ShareExtensionFlowModel.swift
//  BalibuShareExtension
//
//  Machine à états : chargement → (sélection) → crop → confirmation + session Railway (App Group).
//

import Combine
import SwiftUI
import UIKit

@MainActor
final class ShareFlowModel: ObservableObject {
    enum Phase {
        case loading
        case loadingLink
        case pickCandidates([UIImage])
        case crop(UIImage)
        case confirmReady
        case error(String)
    }

    @Published private(set) var phase: Phase = .loading

    weak var extensionContext: NSExtensionContext?

    /// Référence au contrôleur de crop (export JPEG).
    weak var cropController: ShareSquareCropEditorViewController?

    /// URL de page d’origine si import lien (métadonnées payload).
    private(set) var linkSourceURL: String?

    /// Aperçu de l’image recadrée sur l’écran de confirmation.
    @Published private(set) var confirmPreviewImage: UIImage?

    /// Pendant l’appel POST /search-sessions (désactive le bouton Analyser).
    @Published private(set) var isStartingRemoteSession = false

    /// Résultat de la programmation de la notification locale après démarrage de session.
    @Published private(set) var notificationScheduleOutcome: ShareNotificationScheduleOutcome?

    private let linkResolver: ShareLinkResolving

    private var sessionPollingTask: Task<Void, Never>?

    init(extensionContext: NSExtensionContext?, linkResolver: ShareLinkResolving = CompositeShareLinkResolver()) {
        self.extensionContext = extensionContext
        self.linkResolver = linkResolver
    }

    func startLoading() {
        phase = .loading
        Task { await loadSharedContent() }
    }

    private func loadSharedContent() async {
        guard let ctx = extensionContext else {
            phase = .error("Contexte de partage indisponible.")
            return
        }

        guard let content = await ShareItemExtractor.extractContent(from: ctx) else {
            phase = .error("Aucune image ou lien exploitable.")
            return
        }

        switch content {
        case .image(let data):
            guard let ui = UIImage(data: data) else {
                phase = .error("Image illisible.")
                return
            }
            linkSourceURL = nil
            phase = .crop(ui)

        case .link(let url):
            linkSourceURL = url.absoluteString
            phase = .loadingLink
            do {
                let images = try await linkResolver.loadCandidateImages(from: url)
                if images.count == 1, let first = images.first {
                    phase = .crop(first)
                } else if images.count > 1 {
                    phase = .pickCandidates(images)
                } else {
                    phase = .error("Aucune image trouvée pour ce lien.")
                }
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    func selectCandidate(_ image: UIImage) {
        phase = .crop(image)
    }

    /// Après recadrage : enregistre l’image dans l’App Group, lance Railway (`POST /search-sessions`), puis l’écran de chargement réel.
    func commitCropAndStartBackendSearch() {
        guard let cropped = cropController?.exportCroppedImage(),
              let data = cropped.jpegData(compressionQuality: 0.88) else {
            phase = .error("Impossible d’exporter l’image recadrée.")
            return
        }

        isStartingRemoteSession = true
        notificationScheduleOutcome = nil
        sessionPollingTask?.cancel()

        Task {
            do {
                let fileName = try ShareExtensionStorage.saveJPEGToSharedImagesOnly(data)
                let start = try await ShareExtensionSearchAPI.startSearchSession(imageData: data)

                let pending = PendingSharedSearchSession(
                    sessionId: start.sessionId,
                    createdAt: Date(),
                    source: "share_extension",
                    status: start.status,
                    previewImagePath: nil,
                    originalImagePath: fileName,
                    searchQuery: start.searchQuery,
                    completedResultJSONFileName: nil
                )
                try SharedSearchSessionStore.shared.save(pending)

                await MainActor.run {
                    confirmPreviewImage = cropped
                    phase = .confirmReady
                }

                let outcome = await ShareExtensionNotificationScheduler.scheduleResultsReady(sessionId: start.sessionId)
                await MainActor.run {
                    notificationScheduleOutcome = outcome
                }

                sessionPollingTask = Task {
                    await Self.pollRemoteSession(sessionId: start.sessionId)
                }
            } catch {
                await MainActor.run {
                    phase = .error(String(localized: "Impossible de lancer l’analyse : \(error.localizedDescription)"))
                }
            }
            await MainActor.run {
                isStartingRemoteSession = false
            }
        }
    }

    private nonisolated static func pollRemoteSession(sessionId: String) async {
        let maxIterations = 80
        for _ in 0..<maxIterations {
            if Task.isCancelled { return }
            do {
                let data = try await ShareExtensionSearchAPI.fetchSessionData(sessionId: sessionId)
                let status = try ShareExtensionSearchAPI.statusString(from: data)
                let query = Self.parseSearchQuery(from: data)
                await MainActor.run {
                    SharedSearchSessionStore.shared.updateStatus(status, searchQuery: query)
                }
                if status == "completed" {
                    let fileName = try ShareExtensionStorage.saveSessionResultJSON(data, sessionId: sessionId)
                    await MainActor.run {
                        SharedSearchSessionStore.shared.updateCompletedResultJSONFileName(fileName)
                        SharedSearchSessionStore.shared.updateStatus("completed", searchQuery: query)
                    }
                    return
                }
                if status == "failed" {
                    await MainActor.run {
                        SharedSearchSessionStore.shared.updateStatus("failed", searchQuery: query)
                    }
                    return
                }
            } catch {
                // Erreur réseau transitoire : on continue à poller.
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }

    private nonisolated static func parseSearchQuery(from jsonData: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any])?["searchQuery"] as? String
    }

    /// Ferme l’extension après confirmation (aucune ouverture de l’app hôte).
    func finishAndDismissExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    func cancelExtension() {
        sessionPollingTask?.cancel()
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
