//
//  ResultsDetailsSheet.swift
//  Balibu
//
//  Sheet : image source, requêtes générées, attributs vision.
//

import SwiftUI

struct ResultsDetailsSheet: View {
    let session: SearchSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacingL) {
                    if let image = session.sourceImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
                    }

                    if !session.generatedQueries.isEmpty {
                        section(title: String(localized: "Requêtes de recherche")) {
                            ForEach(session.generatedQueries, id: \.self) { query in
                                Text(query)
                                    .font(DesignTokens.body)
                                    .foregroundStyle(Color.primary)
                            }
                        }
                    } else if let query = session.generatedQuery {
                        section(title: String(localized: "Requête")) {
                            Text(query)
                                .font(DesignTokens.body)
                                .foregroundStyle(Color.primary)
                        }
                    }

                    if let attrs = session.attributes {
                        section(title: String(localized: "Attributs détectés")) {
                            attributeRow(String(localized: "Catégorie"), attrs.category)
                            attributeRow(String(localized: "Sous-catégorie"), attrs.subcategory)
                            attributeRow(String(localized: "Marque"), attrs.probableBrand)
                            attributeRow(String(localized: "Couleur"), attrs.color)
                            attributeRow(String(localized: "Matière"), attrs.material)
                            attributeRow(String(localized: "Objet"), attrs.dominantItem)
                            if let kw = attrs.styleKeywords, !kw.isEmpty {
                                attributeRow(String(localized: "Mots-clés"), kw.joined(separator: ", "))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.spacingM)
            }
            .background(DesignTokens.background)
            .navigationTitle(String(localized: "Détails"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Fermer")) { dismiss() }
                }
            }
        }
    }

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            Text(title)
                .font(DesignTokens.headline)
                .foregroundStyle(Color.primary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.spacingM)
        .background(DesignTokens.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
    }

    private func attributeRow(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(DesignTokens.caption)
                .foregroundStyle(Color.secondary)
            Spacer(minLength: 8)
            Text(value?.isEmpty == false ? value! : "—")
                .font(DesignTokens.body)
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}
