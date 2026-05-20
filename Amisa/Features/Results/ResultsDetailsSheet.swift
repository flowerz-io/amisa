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
                    section(title: String(localized: "Type de recherche")) {
                        Text(session.isTextOnlySearch
                             ? String(localized: "Recherche texte (Vinted)")
                             : String(localized: "Analyse d’image"))
                            .font(DesignTokens.body)
                            .foregroundStyle(Color.primary)
                    }

                    if let image = session.sourceImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
                    }

                    if session.isTextOnlySearch, session.attributes == nil {
                        Text(String(localized: "Aucun attribut issu de la vision : les résultats suivent uniquement ta requête texte."))
                            .font(DesignTokens.caption)
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                            attributeRow(
                                String(localized: "Identification"),
                                identificationDisplay(attrs)
                            )
                            attributeRow(String(localized: "Marque"), attrs.probableBrand)
                            attributeRow(
                                String(localized: "Modèle"),
                                modelDisplay(attrs)
                            )
                            attributeRow(
                                String(localized: "Coloris"),
                                colorwayDisplay(attrs)
                            )
                            attributeRow(
                                String(localized: "Catégorie"),
                                categoryDisplay(attrs)
                            )
                            attributeRow(String(localized: "Matière"), attrs.material)
                            if let confText = confidenceDisplay(attrs.confidence) {
                                attributeRow(String(localized: "Confiance"), confText)
                            }
                            if let vr = attrs.visualReasoning?.trimmingCharacters(in: .whitespacesAndNewlines), !vr.isEmpty {
                                attributeRow(String(localized: "Indices visuels"), vr)
                            }
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

    /// Identification complète (nouveau champ) ou composition legacy.
    private func identificationDisplay(_ attrs: FashionVisionResult) -> String? {
        if let fi = attrs.fullIdentification?.trimmingCharacters(in: .whitespacesAndNewlines), !fi.isEmpty {
            return fi
        }
        let parts: [String] = [
            attrs.probableBrand,
            attrs.exactModel ?? attrs.inferredModel,
            attrs.colorway ?? attrs.color ?? attrs.dominantColorPrecise,
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        if let d = attrs.dominantItem?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty { return d }
        return nil
    }

    private func modelDisplay(_ attrs: FashionVisionResult) -> String? {
        let m = (attrs.exactModel ?? attrs.inferredModel)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let m, !m.isEmpty { return m }
        return nil
    }

    private func colorwayDisplay(_ attrs: FashionVisionResult) -> String? {
        let c = (attrs.colorway ?? attrs.color ?? attrs.dominantColorPrecise)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let c, !c.isEmpty { return c }
        return nil
    }

    private func categoryDisplay(_ attrs: FashionVisionResult) -> String? {
        let c = attrs.category?.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = attrs.subcategory?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (c, s) {
        case let (cat?, sub?) where !cat.isEmpty && !sub.isEmpty:
            return "\(cat) · \(sub)"
        case let (cat?, _) where !cat.isEmpty:
            return cat
        case let (_, sub?) where !sub.isEmpty:
            return sub
        default:
            return attrs.itemTypeCanonical?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func confidenceDisplay(_ value: Double?) -> String? {
        guard let value else { return nil }
        let pct = max(0, min(100, Int((value * 100).rounded())))
        return "\(pct) %"
    }
}
