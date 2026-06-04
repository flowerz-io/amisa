//
//  RecentPhotosStrip.swift
//  Balibu
//
//  Ruban horizontal de miniatures (photothèque récente) + bouton "ouvrir tout" en fin de liste.
//

import Combine
import Photos
import SwiftUI
import UIKit

@MainActor
final class RecentPhotosLibraryModel: ObservableObject {
    @Published private(set) var assets: [PHAsset] = []
    @Published private(set) var authStatus: PHAuthorizationStatus = .notDetermined

    func reload() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authStatus = status
        guard status == .authorized || status == .limited else {
            assets = []
            return
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 40
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var list: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            list.append(asset)
        }
        assets = list
    }

    func requestAccessIfNeeded() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authStatus = status
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] _ in
                guard let model = self else { return }
                Task { @MainActor in
                    model.reload()
                }
            }
        } else {
            reload()
        }
    }

    /// Charge une image pour l’analyse (max 1200 pt côté long).
    static func loadFullImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        opts.resizeMode = .fast
        opts.isSynchronous = false

        let target = CGSize(width: 1200, height: 1200)

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: target,
            contentMode: .aspectFill,
            options: opts
        ) { image, info in
            if (info?[PHImageCancelledKey] as? Bool) == true { return }
            if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
            guard let image else { return }

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    /// @deprecated — préférer `loadFullImage`.
    static func loadImageData(for asset: PHAsset, completion: @escaping (Data?) -> Void) {
        loadFullImage(for: asset) { image in
            completion(image?.jpegData(compressionQuality: 0.88))
        }
    }
}

struct RecentPhotosStrip: View {
    @ObservedObject var library: RecentPhotosLibraryModel
    let onSelectAsset: (PHAsset) -> Void
    var onOpenLibrary: (() -> Void)? = nil

    private let thumbSize: CGFloat = 56

    var body: some View {
        Group {
            switch library.authStatus {
            case .authorized, .limited:
                if library.assets.isEmpty {
                    stripPlaceholder(String(localized: "Aucune photo récente"))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(library.assets, id: \.localIdentifier) { asset in
                                Button {
                                    onSelectAsset(asset)
                                } label: {
                                    RecentPhotoThumbnail(asset: asset, size: thumbSize)
                                }
                                .buttonStyle(.plain)
                                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }

                            if let openLibrary = onOpenLibrary {
                                Button(action: openLibrary) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.white.opacity(0.18))
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(width: thumbSize, height: thumbSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String(localized: "Ouvrir la photothèque"))
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(height: thumbSize + 12)
                }
            case .denied, .restricted:
                stripPlaceholder(String(localized: "Accès à la photothèque refusé"))
            case .notDetermined:
                stripPlaceholder(String(localized: "Autorise l'accès aux photos pour afficher les miniatures."))
            @unknown default:
                stripPlaceholder(String(localized: "Photothèque indisponible"))
            }
        }
    }

    private func stripPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .frame(height: thumbSize + 12)
    }
}

private struct RecentPhotoThumbnail: View {
    let asset: PHAsset
    let size: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
        .onAppear {
            loadThumb()
        }
    }

    private func loadThumb() {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.resizeMode = .fast
        opts.isNetworkAccessAllowed = true
        let scale = UIScreen.main.scale
        let target = CGSize(width: size * scale, height: size * scale)
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: target,
            contentMode: .aspectFill,
            options: opts
        ) { img, _ in
            DispatchQueue.main.async {
                self.image = img
            }
        }
    }
}
