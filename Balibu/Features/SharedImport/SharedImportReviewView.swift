//
//  SharedImportReviewView.swift
//
//  Review : recadrage, tap image = nouvelle photo, Analyser ; chargement = page dédiée.
//

import PhotosUI
import SwiftUI

struct SharedImportReviewView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var viewModel: SharedImportReviewViewModel

    let payload: SharedImagePayload

    @State private var sourceUIImage: UIImage?
    @State private var cropController: SquareCropEditorViewController?
    @State private var cropKey = UUID()
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var phase: PreviewPhase = .editing
    @State private var searchingPreviewThumb: UIImage?

    private enum PreviewPhase {
        case editing
        case searching
    }

    init(payload: SharedImagePayload, apiClient: (any APIClientProtocol)? = nil) {
        self.payload = payload
        _viewModel = StateObject(wrappedValue: SharedImportReviewViewModel(
            payload: payload,
            apiClient: apiClient ?? APIConfig.apiClient
        ))
    }

    var body: some View {
        Group {
            switch phase {
            case .searching:
                LoadingSearchView(
                    previewImage: searchingPreviewThumb,
                    message: String(localized: "Recherche des annonces similaires…")
                )
                .navigationTitle(String(localized: "Review"))
                .navigationBarTitleDisplayMode(.inline)
            case .editing:
                editingContent
            }
        }
        .background(DesignTokens.backgroundColor)
        .onAppear {
            viewModel.setSearchHistoryService(.shared)
            loadSourceImageIfNeeded()
        }
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                guard let newItem else { return }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    await MainActor.run {
                        sourceUIImage = ui
                        cropKey = UUID()
                        viewModel.resetToIdle()
                    }
                }
            }
        }
        .onChange(of: viewModel.searchState) { _, new in
            if case .error = new {
                phase = .editing
            }
        }
    }

    private var editingContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingL) {
                imageSection
                explanationText
                errorBanner

                PrimaryActionButton(
                    title: String(localized: "Analyser"),
                    action: { runSearch() },
                    isDisabled: sourceUIImage == nil
                )
                .padding(.top, DesignTokens.spacingS)
            }
            .padding(.horizontal, DesignTokens.spacingM)
            .padding(.top, DesignTokens.spacingS)
            .padding(.bottom, DesignTokens.spacingXL)
        }
        .navigationTitle(String(localized: "Review"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var imageSection: some View {
        Group {
            if let ui = sourceUIImage {
                VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                            SquareCropEditorRepresentable(image: ui) { controller in
                                cropController = controller
                            }
                            .id(cropKey)
                            .frame(height: 360)

                            Text(String(localized: "Appuie pour changer la photo · déplace et pince pour cadrer."))
                                .font(DesignTokens.captionFont)
                                .foregroundStyle(DesignTokens.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM)
                        .fill(DesignTokens.cardBackground)
                        .frame(height: 200)
                        .overlay {
                            VStack(spacing: DesignTokens.spacingS) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.largeTitle)
                                Text(String(localized: "Choisir une photo"))
                                    .font(DesignTokens.bodyFont)
                            }
                            .foregroundStyle(DesignTokens.textSecondary)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var explanationText: some View {
        Text(String(localized: "Nous analysons l’image et cherchons des articles similaires sur les marketplaces."))
            .font(DesignTokens.bodyFont)
            .foregroundStyle(DesignTokens.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if case .error(let message) = viewModel.searchState {
            VStack(spacing: DesignTokens.spacingXS) {
                Text(message)
                    .font(DesignTokens.captionFont)
                    .foregroundStyle(DesignTokens.errorColor)
                    .multilineTextAlignment(.center)
                Text(String(localized: "Tu peux corriger et appuyer sur Analyser pour réessayer."))
                    .font(DesignTokens.captionFont)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func loadSourceImageIfNeeded() {
        guard sourceUIImage == nil,
              let url = payload.imageURL,
              let data = try? Data(contentsOf: url),
              let ui = UIImage(data: data) else { return }
        sourceUIImage = ui
    }

    private func runSearch() {
        guard let controller = cropController else {
            viewModel.setErrorMessage(String(localized: "Le cadre n’est pas prêt. Réessaie dans un instant."))
            return
        }
        guard let cropped = controller.exportCroppedImage() else {
            viewModel.setErrorMessage(String(localized: "Impossible d’exporter la zone sélectionnée."))
            return
        }
        searchingPreviewThumb = cropped
        phase = .searching
        viewModel.startSearch(croppedImage: cropped) { session in
            router.navigateToResults(session: session)
        }
    }
}

#Preview {
    NavigationStack {
        SharedImportReviewView(payload: SharedImagePayload(imageFileName: "preview.jpg"))
            .environmentObject(Router())
    }
}
