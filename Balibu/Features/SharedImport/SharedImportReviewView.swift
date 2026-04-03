//
//  SharedImportReviewView.swift
//  Balibu
//
//  Created for Balibu MVP.
//

import SwiftUI

struct SharedImportReviewView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var viewModel: SharedImportReviewViewModel

    let payload: SharedImagePayload

    @State private var sourceUIImage: UIImage?
    @State private var cropController: SquareCropEditorViewController?

    init(payload: SharedImagePayload, apiClient: (any APIClientProtocol)? = nil) {
        self.payload = payload
        _viewModel = StateObject(wrappedValue: SharedImportReviewViewModel(
            payload: payload,
            apiClient: apiClient ?? APIConfig.apiClient
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingXL) {
                imageSection
                explanationText
                actionSection
            }
            .padding(DesignTokens.spacingL)
        }
        .background(DesignTokens.backgroundColor)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cleanupAndDismiss { router.popToRoot() }
                }
            }
        }
        .onAppear {
            viewModel.setSearchHistoryService(.shared)
            loadSourceImageIfNeeded()
        }
    }

    private var imageSection: some View {
        Group {
            if let ui = sourceUIImage {
                VStack(spacing: DesignTokens.spacingS) {
                    SquareCropEditorRepresentable(image: ui) { controller in
                        cropController = controller
                    }
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM))

                    Text(String(localized: "Déplace et pince pour cadrer l’article dans le carré."))
                        .font(DesignTokens.captionFont)
                        .foregroundColor(DesignTokens.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM)
                    .fill(DesignTokens.cardBackground)
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: DesignTokens.spacingS) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                            Text("Image not available")
                                .font(DesignTokens.bodyFont)
                        }
                        .foregroundColor(DesignTokens.textSecondary)
                    }
            }
        }
    }

    private func loadSourceImageIfNeeded() {
        guard sourceUIImage == nil,
              let url = payload.imageURL,
              let data = try? Data(contentsOf: url),
              let ui = UIImage(data: data) else { return }
        sourceUIImage = ui
    }

    private var explanationText: some View {
        Text("We'll analyze this image and find similar items on resale marketplaces.")
            .font(DesignTokens.bodyFont)
            .foregroundColor(DesignTokens.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionSection: some View {
        VStack(spacing: DesignTokens.spacingM) {
            switch viewModel.searchState {
            case .idle, .error:
                Button {
                    runSearch()
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search resale matches")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.spacingL)
                }
                .buttonStyle(BalibuButtonStyle())
                .disabled(viewModel.searchState == .loading || sourceUIImage == nil)

            case .loading:
                LoadingView(message: "Analyzing image…")

            case .success:
                EmptyView()
            }

            if case .error(let message) = viewModel.searchState {
                VStack(spacing: DesignTokens.spacingS) {
                    Text(message)
                        .font(DesignTokens.captionFont)
                        .foregroundColor(DesignTokens.errorColor)
                        .multilineTextAlignment(.center)
                    Text("Tap the button above to try again.")
                        .font(DesignTokens.captionFont)
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
        }
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
