//
//  InstagramLinkFallbackView.swift
//  BalibuShareExtension
//

import SwiftUI

struct InstagramLinkFallbackView: View {
    let sharedURL: URL
    let previewImage: UIImage?
    let onPasteImage: () -> Void
    let onPickFromPhotos: () -> Void
    let onUseLinkPreview: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(String(localized: "Ajoute l’image à analyser"))
                    .font(.title3.weight(.semibold))
                Text(String(localized: "Instagram a partagé un lien. Ajoute une capture ou une image pour lancer la recherche."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(action: onPasteImage) {
                    Text(String(localized: "Coller une image"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: onPickFromPhotos) {
                    Text(String(localized: "Choisir dans Photos"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if let previewImage {
                    Button(action: onUseLinkPreview) {
                        HStack(spacing: 10) {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 34, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Text(String(localized: "Utiliser l’aperçu du lien"))
                                .font(.footnote)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Button(action: onCancel) {
                    Text(String(localized: "Annuler"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Text(sharedURL.absoluteString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }
}
