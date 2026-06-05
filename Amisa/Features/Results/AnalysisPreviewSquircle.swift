//
//  AnalysisPreviewSquircle.swift
//

import SwiftUI

struct AnalysisPreviewSquircle: View {
    let image: Image
    let size: CGFloat

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)

            image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(
                cornerRadius: size * 0.26,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: size * 0.26,
                style: .continuous
            )
            .strokeBorder(Color.primary.opacity(AmisaChrome.analyzedImageBorderOpacity), lineWidth: 0.5)
        )
        .clipped()
        .drawingGroup()
    }
}
