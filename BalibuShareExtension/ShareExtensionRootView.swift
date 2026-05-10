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
                .navigationBarHidden(model.state.isPreview)
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
        case .resolving:
            VStack(spacing: 16) {
                ProgressView()
                Text(String(localized: "Préparation du partage…"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .preview(let uiImage):
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        Color.clear.frame(height: geo.safeAreaInsets.top + 56)

                        GoogleLensCropRepresentable(image: uiImage) { controller in
                            model.cropController = controller
                        }
                        .frame(height: geo.size.height * 0.70)
                        .background(Color.black)

                        extensionBottomPanel(geo: geo)
                    }

                    extensionHeader(safeTop: geo.safeAreaInsets.top)
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

    // MARK: - Panel inférieur (preview)

    @ViewBuilder
    private func extensionBottomPanel(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            Text(String(localized: "Déplace et pince pour cadrer · fais glisser les coins pour recadrer."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            Spacer(minLength: 10)

            Text(String(localized: "Nous analysons l'image et cherchons des articles similaires sur les marketplaces."))
                .font(.footnote)
                .foregroundStyle(Color(uiColor: .systemGray2))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer(minLength: 16)

            ShareExtensionPrimaryActionButton(
                title: String(localized: "Analyser"),
                action: { model.commitCropAndStartBackendSearch() },
                isDisabled: model.isStartingRemoteSession
            )
            .padding(.horizontal, 24)
            .padding(.bottom, max(geo.safeAreaInsets.bottom + 12, 28))
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(uiColor: .systemBackground).opacity(0.07)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Header custom

    private func extensionHeader(safeTop: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: safeTop + 72)
            .frame(maxWidth: .infinity)

            HStack {
                Button { model.cancelExtension() } label: {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(String(localized: "Review"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, safeTop + 6)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Loading / confirm

    @ViewBuilder
    private func confirmReadyContent(model: ShareFlowModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                if case .loading(let preview) = model.state {
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
            Text(String(localized: "La notification n'a pas pu être planifiée (\(message)). Ouvre Balibu pour lancer la recherche — ton analyse est enregistrée."))
        case .none:
            EmptyView()
        }
    }
}

// MARK: - ShareFlowState helper

private extension ShareFlowState {
    var isPreview: Bool {
        if case .preview = self { return true }
        return false
    }
}
