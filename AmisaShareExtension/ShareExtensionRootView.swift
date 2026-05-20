//
//  ShareExtensionRootView.swift
//  BalibuShareExtension
//
//  UI SwiftUI du flux partage — Review façon Google Lens.
//

import SwiftUI

struct ShareExtensionRootView: View {
    @StateObject private var model: ShareFlowModel

    init(extensionContext: NSExtensionContext?) {
        _model = StateObject(wrappedValue: ShareFlowModel(extensionContext: extensionContext))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationBarHidden(model.state.shouldHideSystemNavigationBar)
                .navigationTitle(String(localized: "Amisa"))
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
        case .resolving:
            VStack(spacing: 16) {
                ProgressView()
                Text(String(localized: "Préparation du partage…"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))

        case .resolvingURLPreview:
            VStack(spacing: 16) {
                ProgressView()
                Text(String(localized: "Chargement de l'aperçu…"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))

        case .preview(let uiImage):
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    Color(uiColor: .systemGroupedBackground)
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        Color.clear.frame(height: geo.safeAreaInsets.top + 66)

                        Color.clear.frame(height: 30)

                        GoogleLensCropRepresentable(image: uiImage) { controller in
                            model.cropController = controller
                        }
                        .frame(height: geo.size.height * 0.56)
                        .background(Color(uiColor: .secondarySystemFill))

                        extensionBottomPanel(geo: geo)
                    }

                    extensionHeader(safeTop: geo.safeAreaInsets.top)
                        .zIndex(9_999)
                }
            }
            .ignoresSafeArea(edges: .top)

        case .videoFramePicker(let videoURL):
            VideoFramePickerView(
                videoURL: videoURL,
                onSelectFrame: { model.setPickedVideoFrame($0) },
                onCancel: { model.cancelExtension() }
            )

        case .loading:
            GeometryReader { geo in
                let safeTop = geo.safeAreaInsets.top
                /// Décale le scroll sous la barre chrome système (Fermer + titre).
                let loadingChromeBottom = safeTop + 18 + 44 + 12

                ZStack(alignment: .top) {
                    ShareExtensionResultsTeaserView(model: model)
                        .padding(.top, loadingChromeBottom)

                    ShareExtensionLoadingTopChrome(safeTop: safeTop) {
                        model.cancelExtension()
                    }
                    .zIndex(9_999)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

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
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    // MARK: - Panel inférieur (preview)

    @ViewBuilder
    private func extensionBottomPanel(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 18)

            Text(String(localized: "Tu peux déplacer ou redimensionner la zone comme avec une photo classique."))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)

            Spacer(minLength: 10)

            ShareExtensionAnalyzeChromeButton(
                title: String(localized: "Analyser"),
                action: { model.commitCropAndStartBackendSearch() },
                isDisabled: model.isStartingRemoteSession
            )
            .padding(.top, 12)
            .offset(y: 20)
            .padding(.bottom, max(geo.safeAreaInsets.bottom + 12, 28))
        }
        .background(.regularMaterial)
    }

    // MARK: - Header custom

    private func extensionHeader(safeTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: safeTop + 66)
                .overlay(alignment: .bottom) {
                    HStack {
                        ShareExtensionLiquidGlassDismissButton {
                            model.cancelExtension()
                        }
                        .offset(y: 10)

                        Spacer()

                        Text(String(localized: "Review"))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)

                        Spacer()

                        Color.clear.frame(width: 58, height: 58)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(true)
    }
}

// MARK: - Chrome « loading » (nav système masquée)

private struct ShareExtensionLoadingTopChrome: View {
    let safeTop: CGFloat
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(String(localized: "Fermer"), action: onClose)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Spacer()

                Text(String(localized: "Amisa"))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Color.clear.frame(width: 64, height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, safeTop + 18)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - ShareFlowState helper

private extension ShareFlowState {
    /// Masque la barre système : Review plein écran custom + step résultats avec chrome dédié.
    var shouldHideSystemNavigationBar: Bool {
        switch self {
        case .preview, .loading:
            return true
        default:
            return false
        }
    }
}
