//
//  LoadingSearchView.swift
//  Balibu
//
//  Page plein écran dédiée au chargement après « Analyser » ou recherche texte.
//

import SwiftUI
import UIKit

enum LoadingSearchPreview {
    case image(UIImage?)
    case text(String)
}

struct LoadingSearchView: View {
    let preview: LoadingSearchPreview
    let message: String

    init(preview: LoadingSearchPreview, message: String) {
        self.preview = preview
        self.message = message
    }

    init(previewImage: UIImage?, message: String) {
        self.preview = .image(previewImage)
        self.message = message
    }

    init(textQuery: String, message: String) {
        self.preview = .text(textQuery)
        self.message = message
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingL) {
            previewBlock

            LoadingProgressBlock(message: message)
        }
        .padding(.horizontal, DesignTokens.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.backgroundColor)
    }

    @ViewBuilder
    private var previewBlock: some View {
        switch preview {
        case .image(let img):
            if let img {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            }

        case .text(let query):
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)

                Text(query)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .padding(24)
            }
            .frame(width: 120, height: 120)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
    }
}
