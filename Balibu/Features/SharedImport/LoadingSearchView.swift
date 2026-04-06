//
//  LoadingSearchView.swift
//  Balibu
//
//  Page plein écran dédiée au chargement après « Analyser ».
//

import SwiftUI

struct LoadingSearchView: View {
    let previewImage: UIImage?
    let message: String

    var body: some View {
        VStack(spacing: DesignTokens.spacingL) {
            if let img = previewImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            }

            LoadingProgressBlock(message: message)
        }
        .padding(.horizontal, DesignTokens.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.backgroundColor)
    }
}
