//
//  SharedImportReviewView.swift
//
//  Review façon Google Lens :
//  - fond adaptatif light/dark
//  - bouton retour AccentColor → rouvre la caméra
//  - grande zone image Google Lens
//  - bouton Analyser en bas
//

import SwiftUI

struct SharedImportReviewView: View {
    @EnvironmentObject private var router: Router
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: SharedImportReviewViewModel

    let payload: SharedImagePayload

    @State private var sourceUIImage: UIImage?
    @State private var cropController: GoogleLensCropViewController?
    @State private var cropKey = UUID()
    @State private var phase: PreviewPhase = .editing
    @State private var searchingPreviewThumb: UIImage?

    private enum PreviewPhase {
        case editing
        case searching
    }

    private var reviewBackground: Color {
        colorScheme == .dark ? .black : Color(.systemBackground)
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
            case .editing:
                editingView
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            router.isTabBarHidden = true
            viewModel.setSearchHistoryService(.shared)
            loadSourceImageIfNeeded()
        }
        .onDisappear {
            router.isTabBarHidden = false
        }
        .onChange(of: viewModel.searchState) { _, new in
            if case .error = new { phase = .editing }
        }
    }

    // MARK: - Editing layout

    private var editingView: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                reviewBackground.ignoresSafeArea()

                // Contenu vertical
                VStack(spacing: 0) {
                    // Espace réservé pour le header : safeTop + 26 (padding) + 50 (bouton) + 20 (respiration)
                    Color.clear
                        .frame(height: geo.safeAreaInsets.top + 96)

                    // Zone image (Google Lens)
                    cropZone(geo: geo)

                    // Panel inférieur
                    bottomPanel(geo: geo)
                }

                // Header custom (positionné en overlay)
                customHeader(safeTop: geo.safeAreaInsets.top)
                    .zIndex(9_999)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Zone image

    @ViewBuilder
    private func cropZone(geo: GeometryProxy) -> some View {
        let imageHeight = geo.size.height * 0.52

        if let ui = sourceUIImage {
            GoogleLensCropRepresentable(image: ui) { controller in
                cropController = controller
            }
            .id(cropKey)
            .frame(height: imageHeight)
            .background(reviewBackground)
        } else {
            ZStack {
                reviewBackground
                ProgressView()
                    .tint(.secondary)
            }
            .frame(height: imageHeight)
        }
    }

    // MARK: - Panel inférieur

    @ViewBuilder
    private func bottomPanel(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 18)

            Text(String(localized: "Tu peux déplacer ou redimensionner la zone comme avec une photo classique."))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .offset(y: -20)

            if case .error(let message) = viewModel.searchState {
                errorBanner(message: message)
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 12)

            AnalyzeGlowChromeButton(
                title: String(localized: "Analyser"),
                action: { runSearch() },
                isDisabled: sourceUIImage == nil
            )
            .padding(.bottom, max(geo.safeAreaInsets.bottom + 8, 20))
        }
    }

    // MARK: - Bannière d'erreur

    private func errorBanner(message: String) -> some View {
        VStack(spacing: 4) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
            Text(String(localized: "Tu peux corriger et appuyer sur Analyser pour réessayer."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Header custom

    private func customHeader(safeTop: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Bouton retour — AccentColor, 50×50
            Button {
                router.goBackToCamera()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: Color.accentColor.opacity(0.30), radius: 7, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .offset(y: 10)

            Spacer()

            Text(String(localized: "Review"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            // Miroir pour centrer le titre
            Color.clear.frame(width: 50, height: 50)
        }
        .padding(.horizontal, 20)
        .padding(.top, safeTop + 26)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logic

    private func loadSourceImageIfNeeded() {
        guard sourceUIImage == nil,
              let url = payload.imageURL,
              let data = try? Data(contentsOf: url),
              let ui = UIImage(data: data) else { return }
        sourceUIImage = ui
    }

    private func runSearch() {
        guard let controller = cropController else {
            viewModel.setErrorMessage(String(localized: "Le cadre n'est pas prêt. Réessaie dans un instant."))
            return
        }
        guard let cropped = controller.exportCroppedImage() else {
            viewModel.setErrorMessage(String(localized: "Impossible d'exporter la zone sélectionnée."))
            return
        }
        searchingPreviewThumb = cropped
        phase = .searching
        Task {
            await runSearchPipeline(cropped: cropped)
        }
    }

    private func runSearchPipeline(cropped: UIImage) async {
        let presetId = UUID()
        let coordinator = AnalyzeFetchCoordinator()

        let package: (Data, String)
        do {
            package = try viewModel.preparePersistedImage(from: cropped)
        } catch {
            await MainActor.run {
                viewModel.setErrorMessage(error.localizedDescription)
                phase = .editing
            }
            return
        }
        let (imageData, fileName) = package

        let fetchTask = Task {
            await coordinator.run {
                try await viewModel.fetchCompletedImageSession(
                    imageData: imageData,
                    presetId: presetId,
                    savedFileName: fileName
                )
            }
        }

        try? await Task.sleep(nanoseconds: FullscreenSearchTiming.photoNanoseconds)

        let outcome = await coordinator.peekOutcome()

        await MainActor.run {
            switch outcome {
            case .success(let session):
                router.navigateToResults(session: session)

            case .failure(let error):
                viewModel.setErrorMessage(error.localizedDescription)
                phase = .editing
                fetchTask.cancel()

            case nil:
                let placeholder = viewModel.hydratingPlaceholderSession(presetId: presetId, savedFileName: fileName)
                router.navigateToResults(session: placeholder)
                Task {
                    await fetchTask.value
                    let final = await coordinator.peekOutcome()
                    await MainActor.run {
                        switch final {
                        case .success(let s):
                            NotificationCenter.default.post(name: .amisaSearchSessionHydrated, object: s)
                        case .failure(let err):
                            NotificationCenter.default.post(
                                name: .amisaSearchHydrationFailed,
                                object: err.localizedDescription
                            )
                        case nil:
                            break
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SharedImportReviewView(payload: SharedImagePayload(imageFileName: "preview.jpg"))
            .environmentObject(Router())
    }
}
