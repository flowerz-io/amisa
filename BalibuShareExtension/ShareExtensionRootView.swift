//
//  ShareExtensionRootView.swift
//  BalibuShareExtension
//
//  UI SwiftUI minimaliste pour le flux partage (alignée visuellement sur la Preview native).
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
        switch model.phase {
        case .loading:
            VStack(spacing: 16) {
                ProgressView()
                Text(String(localized: "Chargement…"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loadingLink:
            VStack(spacing: 16) {
                ProgressView()
                Text(String(localized: "Récupération de l’image depuis le lien…"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .pickCandidates(let images):
            ShareCandidatePickerView(images: images) { selected in
                model.selectCandidate(selected)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .crop(let uiImage):
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

        case .confirmReady:
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
                if let preview = model.confirmPreviewImage {
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

// MARK: - Sélection si plusieurs images (MVP : grille simple)

private struct ShareCandidatePickerView: View {
    let images: [UIImage]
    let onSelect: (UIImage) -> Void

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Choisir une image"))
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<images.count, id: \.self) { idx in
                    Button {
                        onSelect(images[idx])
                    } label: {
                        Image(uiImage: images[idx])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
}
