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

    private var reviewBackground: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color(white: 0.06), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
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
            let safeTop = EffectiveSafeArea.topInset(proxy: geo)

            ZStack(alignment: .top) {
                reviewBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: reviewHeaderReservedHeight(safeTop: safeTop))

                    cropZone(geo: geo)
                    bottomPanel(geo: geo)
                }

                customHeader(safeTop: safeTop)
                    .zIndex(9_999)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    /// Espace sous la Dynamic Island : safe top + 10 pt + rangée 44 pt + respiration.
    private func reviewHeaderReservedHeight(safeTop: CGFloat) -> CGFloat {
        safeTop + 10 + 44 + 12
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
            .padding(.horizontal, 16)
            .clipShape(RoundedRectangle(cornerRadius: AmisaChrome.reviewCropContainerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AmisaChrome.reviewCropContainerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 16, x: 0, y: 8)
            .padding(.horizontal, 4)
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
            Button {
                router.goBackToCamera()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(reviewBackButtonFill)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.22), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(ReviewBackButtonStyle())
            .accessibilityLabel(String(localized: "Retour"))

            Spacer()

            Text(String(localized: "Ajuster"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignTokens.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, safeTop + 10)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var reviewBackButtonFill: Color {
        Color.black.opacity(colorScheme == .dark ? 0.44 : 0.40)
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

// MARK: - Bouton retour Review

private struct ReviewBackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        SharedImportReviewView(payload: SharedImagePayload(imageFileName: "preview.jpg"))
            .environmentObject(Router())
    }
}
