//
//  SharedImportReviewView.swift
//
//  Review : recadrage, tap image = nouvelle photo, Analyser en bas.
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

    init(payload: SharedImagePayload, apiClient: (any APIClientProtocol)? = nil) {
        self.payload = payload
        _viewModel = StateObject(wrappedValue: SharedImportReviewViewModel(
            payload: payload,
            apiClient: apiClient ?? APIConfig.apiClient
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingL) {
                imageSection
                explanationText
                errorBanner
            }
            .padding(.horizontal, DesignTokens.spacingM)
            .padding(.top, DesignTokens.spacingS)
        }
        .background(DesignTokens.backgroundColor)
        .navigationTitle(String(localized: "Review"))
        .navigationBarTitleDisplayMode(.inline)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomActionBar
                .background(.ultraThinMaterial)
        }
    }

    private var imageSection: some View {
        Group {
            if let ui = sourceUIImage {
                VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        VStack(spacing: DesignTokens.spacingXS) {
                            SquareCropEditorRepresentable(image: ui) { controller in
                                cropController = controller
                            }
                            .id(cropKey)
                            .frame(height: 360)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM))

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

    @ViewBuilder
    private var bottomActionBar: some View {
        VStack(spacing: DesignTokens.spacingS) {
            switch viewModel.searchState {
            case .loading:
                AnalysisLoadingView()
                    .padding(.vertical, DesignTokens.spacingS)
            case .idle, .error, .success:
                Button {
                    runSearch()
                } label: {
                    Text(String(localized: "Analyser"))
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.spacingM)
                }
                .buttonStyle(BalibuButtonStyle())
                .disabled(sourceUIImage == nil)
            }
        }
        .padding(.horizontal, DesignTokens.spacingM)
        .padding(.top, DesignTokens.spacingS)
        .padding(.bottom, DesignTokens.spacingXS)
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
