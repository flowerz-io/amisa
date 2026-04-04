//
//  ShareExtensionFlowModel.swift
//  BalibuShareExtension
//
//  Machine à états : chargement → (sélection) → crop → confirmation → deep link.
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

    private(set) var pendingImportId: UUID?

    /// Aperçu de l’image recadrée sur l’écran de confirmation.
    @Published private(set) var confirmPreviewImage: UIImage?

    /// Si `open` vers l’app hôte échoue (completion `false`).
    @Published private(set) var hostAppOpenError: String?

    private let linkResolver: ShareLinkResolving

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

    /// Après recadrage : enregistre dans l’App Group et passe à l’écran de confirmation.
    func commitCropAndPrepareImport() {
        guard let cropped = cropController?.exportCroppedImage(),
              let data = cropped.jpegData(compressionQuality: 0.88) else {
            phase = .error("Impossible d’exporter l’image recadrée.")
            return
        }

        let importId = UUID()
        let fileName = "\(importId.uuidString).jpg"
        let payload = SharedImportPayload(
            id: importId,
            imageFileName: fileName,
            createdAt: Date(),
            sourceURL: linkSourceURL
        )

        do {
            try ShareExtensionStorage.saveImport(payload: payload, imageData: data)
            pendingImportId = importId
            confirmPreviewImage = cropped
            hostAppOpenError = nil
            phase = .confirmReady
        } catch {
            phase = .error("Enregistrement impossible : \(error.localizedDescription)")
        }
    }

    func openHostAppAndFinish() {
        hostAppOpenError = nil
        guard let id = pendingImportId else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        var components = URLComponents()
        components.scheme = "balibu"
        components.host = "shared-import"
        components.queryItems = [URLQueryItem(name: "id", value: id.uuidString)]
        guard let url = components.url else {
            hostAppOpenError = String(localized: "Lien vers Balibu invalide.")
            return
        }
        extensionContext?.open(url, completionHandler: { [weak self] success in
            Task { @MainActor in
                guard let model = self else { return }
                if success {
                    model.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                } else {
                    model.hostAppOpenError = String(localized: "Impossible d’ouvrir Balibu. Ouvrez l’app manuellement ou réessayez.")
                }
            }
        })
    }

    func cancelExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
