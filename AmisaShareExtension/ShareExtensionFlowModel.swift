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
    /// Lien web : métadonnées / og:image en cours (ne pas afficher « aucune image »).
    case resolvingURLPreview(URL)
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
        linkResolver: ShareLinkResolving = CompositeShareLinkResolver()
    ) {
        self.extensionContext = extensionContext
        self.inputResolver = inputResolver
        self.linkResolver = linkResolver
    }

    /// Session Railway active pendant l’écran résultats teaser (pour deep link).
    private(set) var activeSessionId: String?

    private var hasScheduledResultsNotification = false
    private var pendingNotificationOnDismiss = false
    private(set) var remoteSessionStatus: String?

    var loadingPreviewImage: UIImage? {
        if case .loading(let img) = state { return img }
        return nil
    }

    func startLoading() {
        state = .resolving
        teaserListingsFromAPI = []
        activeSessionId = nil
        remoteSessionStatus = nil
        hasScheduledResultsNotification = false
        pendingNotificationOnDismiss = false
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
        hasScheduledResultsNotification = false
        pendingNotificationOnDismiss = false
        remoteSessionStatus = nil
        sessionPollingTask?.cancel()
        teaserListingsFromAPI = []
        print("[SHARE_NOTIFICATION] immediate notification disabled")

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

        let typeSummary = Self.logShareExtensionReceivedTypes(context: ctx)
        print("[ShareExtension] received item types=\(typeSummary)")

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
            print(
                "[ShareExtension] url detected=\(String(url.absoluteString.prefix(200)))"
            )
            if let preview = resolution.previewImage {
                persistResolvedURLPreview(preview)
                setImageForPreview(preview)
                return
            }
            if resolution.platform == .tiktok {
                print("[TIKTOK_FALLBACK_USED]")
            }
            state = .resolvingURLPreview(url)
            Task { await resolveSharedURLPreview(url) }
        case .unknown:
            state = .error(message: "Aucune image, vidéo ou URL exploitable.")
        }
    }

    private func persistResolvedURLPreview(_ image: UIImage) {
        do {
            let data = try ImageUploadPreprocessor.prepareForUpload(image)
            let name = try ShareExtensionStorage.saveJPEGToSharedImagesOnly(data)
            print("[ShareExtension] preview image saved=\(name) bytes=\(data.count)")
        } catch {
            print("[ShareExtension] error=\(error.localizedDescription)")
        }
    }

    private func resolveSharedURLPreview(_ url: URL) async {
        do {
            let images = try await linkResolver.loadCandidateImages(from: url)
            guard let first = images.first else {
                print("[ShareExtension] no usable image after fallbacks")
                state = .error(message: String(localized: "Aucune image exploitable pour ce lien."))
                return
            }
            persistResolvedURLPreview(first)
            setImageForPreview(first)
        } catch {
            print("[ShareExtension] error=\(error.localizedDescription)")
            print("[ShareExtension] no usable image after fallbacks")
            state = .error(message: String(localized: "Aucune image exploitable pour ce lien."))
        }
    }

    private static func logShareExtensionReceivedTypes(context: NSExtensionContext) -> String {
        guard let items = context.inputItems as? [NSExtensionItem] else { return "(none)" }
        var set = Set<String>()
        for item in items {
            guard let attachments = item.attachments else { continue }
            for p in attachments {
                for id in p.registeredTypeIdentifiers {
                    set.insert(id)
                }
            }
        }
        return set.sorted().joined(separator: ", ")
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
                    remoteSessionStatus = status
                    SharedSearchSessionStore.shared.updateStatus(status, searchQuery: query)
                    if !listings.isEmpty {
                        teaserListingsFromAPI = listings
                    }
                    persistContinuitySnapshot(sessionId: sessionId, status: status, query: query, listings: teaserListingsFromAPI)
                }

                print("[SHARE_NOTIFICATION] search status =", status)
                print("[SHARE_NOTIFICATION] results ready listings =", listings.count)

                if status == "completed" {
                    let fileName = try ShareExtensionStorage.saveSessionResultJSON(data, sessionId: sessionId)
                    await MainActor.run {
                        SharedSearchSessionStore.shared.updateCompletedResultJSONFileName(fileName)
                        SharedSearchSessionStore.shared.updateStatus("completed", searchQuery: query)
                        persistContinuitySnapshot(sessionId: sessionId, status: "completed", query: query, listings: teaserListingsFromAPI)
                    }
                    let listingsCount = await MainActor.run { teaserListingsFromAPI.count }
                    await scheduleResultsNotificationIfNeeded(
                        sessionId: sessionId,
                        status: "completed",
                        listingsCount: listingsCount
                    )
                    return
                }
                if status == "failed" {
                    print("[SHARE_NOTIFICATION] skipped reason = search_failed")
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

    /// Indique si l’utilisateur voit déjà des résultats dans l’extension (évite une notification inutile).
    var isUserViewingResultsInExtension: Bool {
        guard case .loading = state else { return false }
        return !teaserListingsFromAPI.isEmpty
    }

    /// Texte d’aide sous la grille pendant la recherche (avant résultats affichés).
    var shouldShowPendingNotificationHint: Bool {
        guard case .loading = state else { return false }
        return teaserListingsFromAPI.isEmpty && remoteSessionStatus != "completed"
    }

    private func previewImageDataForNotification() -> Data? {
        guard let img = loadingPreviewImage else { return nil }
        return try? ImageUploadPreprocessor.prepareForUpload(img)
    }

    private func scheduleResultsNotificationIfNeeded(
        sessionId: String,
        status: String,
        listingsCount: Int
    ) async {
        guard status == "completed" else {
            print("[SHARE_NOTIFICATION] skipped reason = status_not_completed")
            return
        }
        guard listingsCount > 0 else {
            print("[SHARE_NOTIFICATION] skipped reason = zero_results")
            return
        }
        guard !hasScheduledResultsNotification else {
            print("[SHARE_NOTIFICATION] skipped reason = already_scheduled")
            return
        }

        let viewingInExtension = await MainActor.run { isUserViewingResultsInExtension }
        if viewingInExtension {
            await MainActor.run { pendingNotificationOnDismiss = true }
            print("[SHARE_NOTIFICATION] skipped reason = user_viewing_results_in_extension")
            return
        }

        await performScheduleResultsNotification(sessionId: sessionId, listingsCount: listingsCount)
    }

    private func performScheduleResultsNotification(sessionId: String, listingsCount: Int) async {
        let previewData = await MainActor.run { previewImageDataForNotification() }
        let outcome = await ShareExtensionNotificationScheduler.notifySearchResultsReady(
            sessionId: sessionId,
            listingsCount: listingsCount,
            previewImageData: previewData
        )
        await MainActor.run {
            notificationScheduleOutcome = outcome
            if case .scheduled = outcome {
                hasScheduledResultsNotification = true
                pendingNotificationOnDismiss = false
            }
        }
    }

    private func scheduleNotificationOnDismissIfNeeded() async {
        guard pendingNotificationOnDismiss, !hasScheduledResultsNotification else { return }
        guard let sessionId = activeSessionId else { return }
        let count = await MainActor.run { teaserListingsFromAPI.count }
        guard count > 0, remoteSessionStatus == "completed" else {
            print("[SHARE_NOTIFICATION] skipped reason = dismiss_before_ready")
            return
        }
        await performScheduleResultsNotification(sessionId: sessionId, listingsCount: count)
    }

    func finishAndDismissExtension() {
        Task {
            await scheduleNotificationOnDismissIfNeeded()
            await MainActor.run {
                extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
        }
    }

    func cancelExtension() {
        sessionPollingTask?.cancel()
        print("[SHARE_NOTIFICATION] skipped reason = user_cancelled")
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
