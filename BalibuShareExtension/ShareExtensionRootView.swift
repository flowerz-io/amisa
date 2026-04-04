//
//  ShareExtensionRootView.swift
//  BalibuShareExtension
//
//  UI SwiftUI minimaliste pour le flux partage.
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
        .tint(.primary)
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
                    Text(String(localized: "Recadrer"))
                        .font(.headline)

                    ShareSquareCropRepresentable(image: uiImage) { controller in
                        model.cropController = controller
                    }
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text(String(localized: "Déplace et zoome pour cadrer l’article dans le carré."))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        model.commitCropAndPrepareImport()
                    } label: {
                        Text(String(localized: "Enregistrer"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }

        case .confirmReady:
            Group {
                if model.notificationScheduleOutcome == nil {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(String(localized: "Préparation…"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    confirmReadyContent(model: model)
                }
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
        }
    }

    @ViewBuilder
    private func confirmReadyContent(model: ShareFlowModel) -> some View {
        VStack(spacing: 24) {
            if let preview = model.confirmPreviewImage {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "Recherche enregistrée"))
                .font(.title2.weight(.semibold))

            notificationSupplementText(for: model.notificationScheduleOutcome)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                model.finishAndDismissExtension()
            } label: {
                Text(String(localized: "Terminé"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
