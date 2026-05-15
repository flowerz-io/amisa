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
                cornerRadius: size * 0.28,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: size * 0.28,
                style: .continuous
            )
            .stroke(Color.black, lineWidth: 2)
        )
        .clipped()
        .drawingGroup()
    }
}
