//
//  ShareExtensionRootView.swift
//  BalibuShareExtension
//
//  UI SwiftUI minimaliste pour le flux partage (alignée visuellement sur la Preview native).
//

import SwiftUI
import PhotosUI

struct ShareExtensionRootView: View {
    @StateObject private var model: ShareFlowModel
    @State private var isShowingPhotoPicker = false

    init(extensionContext: NSExtensionContext?) {
        _model = StateObject(wrappedValue: ShareFlowModel(extensionContext: extensionContext))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "Balibu"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Fermer")) {
                            model.cancelExtension()
                        }
                    }
                }
        }
        .tint(Color.accentColor)
        .task {
            model.startLoading()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .resolvingInput:
            VStack(spacing: 16) {
                ProgressView()
                Text(String(localized: "Préparation du partage…"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .imagePreview(let uiImage):
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ShareSquareCropRepresentable(image: uiImage) { controller in
                        model.cropController = controller
                    }
                    .frame(height: 360)

                    Text(String(localized: "Déplace et zoome pour cadrer l’article dans le carré."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let source = model.chosenImageSourceLabel {
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(String(localized: "Nous analysons l’image et cherchons des articles similaires sur les marketplaces."))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ShareExtensionPrimaryActionButton(
                        title: String(localized: "Analyser"),
                        action: { model.commitCropAndStartBackendSearch() },
                        isDisabled: model.isStartingRemoteSession
                    )
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))

        case .videoFramePicker(let videoURL):
            VideoFramePickerView(
                videoURL: videoURL,
                onSelectFrame: { model.setPickedVideoFrame($0) },
                onCancel: { model.cancelExtension() }
            )

        case .instagramLinkFallback(let sharedURL, let previewImage):
            InstagramLinkFallbackView(
                sharedURL: sharedURL,
                previewImage: previewImage,
                onPasteImage: { model.useClipboardImage() },
                onPickFromPhotos: { isShowingPhotoPicker = true },
                onUseLinkPreview: { model.useLinkPreview(for: sharedURL) },
                onCancel: { model.cancelExtension() }
            )
            .sheet(isPresented: $isShowingPhotoPicker) {
                SharePhotoPickerSheet { image in
                    guard let image else { return }
                    model.setImageForPreview(image, sourceLabel: String(localized: "Image Photos"))
                }
            }

        case .loadingAnalysis:
            confirmReadyContent(model: model)

        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func confirmReadyContent(model: ShareFlowModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                if case .loadingAnalysis(let preview) = model.state {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                }

                ShareExtensionAnalysisLoadingView()

                notificationSupplementText(for: model.notificationScheduleOutcome)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                ShareExtensionPrimaryActionButton(
                    title: String(localized: "Terminé"),
                    action: { model.finishAndDismissExtension() }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func notificationSupplementText(for outcome: ShareNotificationScheduleOutcome?) -> some View {
        switch outcome {
        case .scheduled:
            Text(String(localized: "Tu recevras une notification pour ouvrir les résultats. Tu peux aussi ouvrir Balibu à tout moment."))
        case .denied:
            Text(String(localized: "Les notifications sont désactivées : tu ne recevras pas de raccourci ici. Ouvre Balibu manuellement pour lancer la recherche — ton analyse est déjà enregistrée. Les futures alertes pour de nouvelles annonces ne fonctionneront pas non plus."))
        case .failed(let message):
            Text(String(localized: "La notification n’a pas pu être planifiée (\(message)). Ouvre Balibu pour lancer la recherche — ton analyse est enregistrée."))
        case .none:
            EmptyView()
        }
    }
}

private struct SharePhotoPickerSheet: UIViewControllerRepresentable {
    let onSelect: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelect: (UIImage?) -> Void

        init(onSelect: @escaping (UIImage?) -> Void) {
            self.onSelect = onSelect
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let first = results.first else {
                onSelect(nil)
                return
            }
            first.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                let image = object as? UIImage
                DispatchQueue.main.async {
                    self.onSelect(image)
                }
            }
        }
    }
}
