//
//  RecentPhotosStrip.swift
//  Balibu
//
//  Ruban horizontal de miniatures (photothèque récente).
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

    /// PHAsset → UIImage (haute qualité, async). Toujours termine (jamais de continuation bloquée).
    static func loadUIImage(from asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let resumed = ContinuationResumeGuard()

            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1600, height: 1600),
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] {
                    print("[RECENTS] PHImage error:", error)
                }

                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    print("[RECENTS] request cancelled")
                    resumed.resumeOnce { continuation.resume(returning: nil) }
                    return
                }

                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) == true

                if let image {
                    if isDegraded {
                        return
                    }
                    resumed.resumeOnce { continuation.resume(returning: image) }
                    return
                }

                if inCloud {
                    print("[RECENTS] asset in iCloud and unavailable locally")
                }

                if !isDegraded {
                    print("[RECENTS] failed to load UIImage (nil result)")
                    resumed.resumeOnce { continuation.resume(returning: nil) }
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: 45_000_000_000)
                resumed.resumeOnce {
                    print("[RECENTS] loadUIImage timeout for:", asset.localIdentifier)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

/// Évite un double `resume` si Photos renvoie plusieurs callbacks.
private final class ContinuationResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func resumeOnce(_ action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        action()
    }
}

// MARK: - Strip

struct RecentPhotosStrip: View {
    @ObservedObject var library: RecentPhotosLibraryModel
    let onSelectAsset: (PHAsset) async -> Void
    var onOpenLibrary: (() -> Void)? = nil

    private let thumbSize: CGFloat = 52

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
                                recentAssetButton(asset)
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
                                }
                                .buttonStyle(.plain)
                                .frame(width: thumbSize, height: thumbSize)
                                .contentShape(Rectangle())
                                .allowsHitTesting(true)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: thumbSize + 12)
                    .zIndex(100)
                    .allowsHitTesting(true)
                }
            case .denied, .restricted:
                stripPlaceholder(String(localized: "Accès à la photothèque refusé"))
            case .notDetermined:
                stripPlaceholder(String(localized: "Autorise l'accès aux photos pour afficher les miniatures."))
            @unknown default:
                stripPlaceholder(String(localized: "Photothèque indisponible"))
            }
        }
        .allowsHitTesting(true)
    }

    private func recentAssetButton(_ asset: PHAsset) -> some View {
        Button {
            print("[RECENTS] tapped asset:", asset.localIdentifier)
            Task {
                await onSelectAsset(asset)
            }
        } label: {
            RecentPhotoThumbnail(asset: asset, size: thumbSize)
                .frame(width: thumbSize, height: thumbSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: thumbSize, height: thumbSize)
        .contentShape(Rectangle())
    }

    private func stripPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .frame(height: thumbSize + 12)
            .allowsHitTesting(false)
    }
}

// MARK: - Thumbnail

struct RecentPhotoThumbnail: View {
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
                .allowsHitTesting(false)
        }
        .onAppear { loadThumb() }
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
