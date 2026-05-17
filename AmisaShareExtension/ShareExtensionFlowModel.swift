//
//  ShareExtensionFlowModel.swift
//  BalibuShareExtension
//
//  Machine à états : chargement → (sélection) → crop → aperçu résultats + session Railway (App Group).
//

import Combine
import SwiftUI
import UIKit

enum ShareFlowState {
    case resolving
    case preview(image: UIImage)
    case videoFramePicker(videoURL: URL)
    case loading(image: UIImage)
    case error(message: String)
}

enum ShareExtensionGridPhase {
    /// Micro-chargement avant skeleton (aucune carte factice).
    case warmingUp
    /// Grille skeleton puis résultats réels.
    case listingGrid
}

@MainActor
final class ShareFlowModel: ObservableObject {
    @Published private(set) var state: ShareFlowState = .resolving
    @Published private(set) var isStartingRemoteSession = false
    @Published private(set) var notificationScheduleOutcome: ShareNotificationScheduleOutcome?
    /// Listings extraits du polling GET — remplissage progressif de la grille teaser.
    @Published private(set) var teaserListingsFromAPI: [ShareExtensionTeaserListing] = []
    @Published private(set) var extensionGridPhase: ShareExtensionGridPhase = .listingGrid

    weak var extensionContext: NSExtensionContext?
    weak var cropController: GoogleLensCropViewController?

    private let inputResolver: SharedInputResolver
    private let linkResolver: ShareLinkResolving
    private var sessionPollingTask: Task<Void, Never>?

    init(
        extensionContext: NSExtensionContext?,
        inputResolver: SharedInputResolver = SharedInputResolver(),
        linkResolver: ShareLinkResolving = BackendShareLinkResolver()
    ) {
        self.extensionContext = extensionContext
        self.inputResolver = inputResolver
        self.linkResolver = linkResolver
    }

    /// Session Railway active pendant l’écran résultats teaser (pour deep link).
    private(set) var activeSessionId: String?

    var loadingPreviewImage: UIImage? {
        if case .loading(let img) = state { return img }
        return nil
    }

    func startLoading() {
        state = .resolving
        teaserListingsFromAPI = []
        activeSessionId = nil
        extensionGridPhase = .listingGrid
        Task { await resolveInitialInput() }
    }

    func setImageForPreview(_ image: UIImage) {
        state = .preview(image: image)
    }

    func setPickedVideoFrame(_ image: UIImage) {
        setImageForPreview(image)
    }

    /// Après recadrage : enregistre l’image dans l’App Group, lance Railway (`POST /search-sessions`), puis teaser + polling.
    func commitCropAndStartBackendSearch() {
        guard let cropped = cropController?.exportCroppedImage(),
              let data = try? ImageUploadPreprocessor.prepareForUpload(cropped) else {
            state = .error(message: "Impossible d’exporter l’image recadrée.")
            return
        }

        isStartingRemoteSession = true
        notificationScheduleOutcome = nil
        sessionPollingTask?.cancel()
        teaserListingsFromAPI = []

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
                    completedResultJSONFileName: nil,
                    continuitySnapshotFileName: nil
                )
                try SharedSearchSessionStore.shared.save(pending)

                await MainActor.run {
                    activeSessionId = start.sessionId
                    extensionGridPhase = .warmingUp
                    state = .loading(image: cropped)
                }

                Task {
                    let ns = UInt64.random(in: 300_000_000 ... 700_000_000)
                    try? await Task.sleep(nanoseconds: ns)
                    await MainActor.run {
                        if case .loading = state {
                            extensionGridPhase = .listingGrid
                        }
                    }
                }

                let outcome = await ShareExtensionNotificationScheduler.scheduleResultsReady(sessionId: start.sessionId)
                await MainActor.run {
                    notificationScheduleOutcome = outcome
                }

                sessionPollingTask = Task { [weak self] in
                    await self?.pollRemoteSession(sessionId: start.sessionId)
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
            setImageForPreview(image)
        case .video(let videoURL):
            if let preview = resolution.previewImage {
                setImageForPreview(preview)
            } else {
                state = .videoFramePicker(videoURL: videoURL)
            }
        case .url(let url):
            if let preview = resolution.previewImage {
                setImageForPreview(preview)
                return
            }
            if resolution.platform == .tiktok {
                print("[TIKTOK_FALLBACK_USED]")
            }
            do {
                let images = try await linkResolver.loadCandidateImages(from: url)
                if let first = images.first {
                    setImageForPreview(first)
                } else {
                    state = .error(message: "Aucune image exploitable dans ce partage.")
                }
            } catch {
                state = .error(message: "Aucune image exploitable dans ce partage.")
            }
        case .unknown:
            state = .error(message: "Aucune image, vidéo ou URL exploitable.")
        }
    }

    private func pollRemoteSession(sessionId: String) async {
        let maxIterations = 80
        for iteration in 0..<maxIterations {
            if Task.isCancelled { return }

            if iteration > 0 {
                let ns: UInt64 = iteration == 1 ? 350_000_000 : 1_200_000_000
                try? await Task.sleep(nanoseconds: ns)
            }

            do {
                let data = try await ShareExtensionSearchAPI.fetchSessionData(sessionId: sessionId)
                let status = try ShareExtensionSearchAPI.statusString(from: data)
                let query = Self.parseSearchQuery(from: data)
                let listings = ShareExtensionTeaserListingParser.listings(from: data)

                await MainActor.run {
                    SharedSearchSessionStore.shared.updateStatus(status, searchQuery: query)
                    if !listings.isEmpty {
                        teaserListingsFromAPI = listings
                    }
                    persistContinuitySnapshot(sessionId: sessionId, status: status, query: query, listings: teaserListingsFromAPI)
                }

                if status == "completed" {
                    let fileName = try ShareExtensionStorage.saveSessionResultJSON(data, sessionId: sessionId)
                    await MainActor.run {
                        SharedSearchSessionStore.shared.updateCompletedResultJSONFileName(fileName)
                        SharedSearchSessionStore.shared.updateStatus("completed", searchQuery: query)
                        persistContinuitySnapshot(sessionId: sessionId, status: "completed", query: query, listings: teaserListingsFromAPI)
                    }
                    return
                }
                if status == "failed" {
                    await MainActor.run {
                        SharedSearchSessionStore.shared.updateStatus("failed", searchQuery: query)
                        persistContinuitySnapshot(sessionId: sessionId, status: "failed", query: query, listings: teaserListingsFromAPI)
                    }
                    return
                }
            } catch {
                // Réseau transitoire : poursuivre le polling.
            }
        }
    }

    private func persistContinuitySnapshot(
        sessionId: String,
        status: String,
        query: String?,
        listings: [ShareExtensionTeaserListing]
    ) {
        do {
            let file = ShareContinuitySnapshotFile(
                schemaVersion: 1,
                sessionId: sessionId,
                savedAt: Date(),
                status: status,
                searchQuery: query,
                listings: listings.map { ShareContinuityListingRow(teaser: $0) }
            )
            let data = try JSONEncoder().encode(file)
            let name = try ShareExtensionStorage.saveContinuitySnapshot(data, sessionId: sessionId)
            SharedSearchSessionStore.shared.updateContinuitySnapshotFileName(name)
        } catch {}
    }

    private nonisolated static func parseSearchQuery(from jsonData: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any])?["searchQuery"] as? String
    }

    func finishAndDismissExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    func cancelExtension() {
        sessionPollingTask?.cancel()
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
