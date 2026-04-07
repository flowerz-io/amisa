//
//  ShareExtensionFlowModel.swift
//  BalibuShareExtension
//
//  Machine à états : chargement → (sélection) → crop → confirmation + session Railway (App Group).
//

import Combine
import SwiftUI
import UIKit

enum ShareFlowState {
    case resolvingInput
    case imagePreview(sourceImage: UIImage)
    case videoFramePicker(videoURL: URL)
    case instagramLinkFallback(sharedURL: URL, previewImage: UIImage?)
    case loadingAnalysis(image: UIImage)
    case error(message: String)
}

@MainActor
final class ShareFlowModel: ObservableObject {
    @Published private(set) var state: ShareFlowState = .resolvingInput
    @Published private(set) var isStartingRemoteSession = false
    @Published private(set) var notificationScheduleOutcome: ShareNotificationScheduleOutcome?
    @Published private(set) var chosenImageSourceLabel: String?

    weak var extensionContext: NSExtensionContext?
    weak var cropController: ShareSquareCropEditorViewController?

    private(set) var linkSourceURL: String?

    private let inputResolver: SharedInputResolver
    private let linkResolver: ShareLinkResolving
    private let clipboardResolver: ClipboardImageResolver
    private var sessionPollingTask: Task<Void, Never>?

    init(
        extensionContext: NSExtensionContext?,
        inputResolver: SharedInputResolver = SharedInputResolver(),
        linkResolver: ShareLinkResolving = BackendShareLinkResolver(),
        clipboardResolver: ClipboardImageResolver = ClipboardImageResolver()
    ) {
        self.extensionContext = extensionContext
        self.inputResolver = inputResolver
        self.linkResolver = linkResolver
        self.clipboardResolver = clipboardResolver
    }

    func startLoading() {
        state = .resolvingInput
        Task { await resolveInitialInput() }
    }

    func setImageForPreview(_ image: UIImage, sourceLabel: String) {
        chosenImageSourceLabel = sourceLabel
        state = .imagePreview(sourceImage: image)
    }

    func setPickedVideoFrame(_ image: UIImage) {
        setImageForPreview(image, sourceLabel: String(localized: "Frame vidéo"))
    }

    func useClipboardImage() {
        guard let image = clipboardResolver.resolveImage() else {
            state = .error(message: String(localized: "Aucune image exploitable dans le presse-papiers."))
            return
        }
        setImageForPreview(image, sourceLabel: String(localized: "Image collée"))
    }

    func useLinkPreview(for sharedURL: URL) {
        state = .resolvingInput
        Task {
            do {
                let images = try await linkResolver.loadCandidateImages(from: sharedURL)
                guard let first = images.first else {
                    state = .error(message: String(localized: "Aucun aperçu image exploitable pour ce lien."))
                    return
                }
                setImageForPreview(first, sourceLabel: String(localized: "Aperçu du lien"))
            } catch {
                state = .error(message: error.localizedDescription)
            }
        }
    }

    /// Après recadrage : enregistre l’image dans l’App Group, lance Railway (`POST /search-sessions`), puis l’écran de chargement réel.
    func commitCropAndStartBackendSearch() {
        guard let cropped = cropController?.exportCroppedImage(),
              let data = cropped.jpegData(compressionQuality: 0.88) else {
            state = .error(message: "Impossible d’exporter l’image recadrée.")
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
                    state = .loadingAnalysis(image: cropped)
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
                    state = .error(message: String(localized: "Impossible de lancer l’analyse : \(error.localizedDescription)"))
                }
            }
            await MainActor.run {
                isStartingRemoteSession = false
            }
        }
    }

    private func resolveInitialInput() async {
        guard let ctx = extensionContext else {
            state = .error(message: "Contexte de partage indisponible.")
            return
        }

        let resolution = await inputResolver.resolve(from: ctx)
        switch resolution.kind {
        case .image(let image):
            linkSourceURL = nil
            setImageForPreview(image, sourceLabel: String(localized: "Image partagée"))
        case .video(let videoURL):
            linkSourceURL = nil
            chosenImageSourceLabel = nil
            state = .videoFramePicker(videoURL: videoURL)
        case .url(let url):
            linkSourceURL = url.absoluteString
            chosenImageSourceLabel = nil
            state = .instagramLinkFallback(sharedURL: url, previewImage: resolution.previewImage)
        case .unknown:
            state = .error(message: "Aucune image, vidéo ou URL exploitable.")
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
