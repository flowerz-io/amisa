//
//  LoadingView.swift
//  Balibu
//
//  Indicateur de chargement premium.
//

import SwiftUI

struct LoadingView: View {
    var message: String = "Analyse en cours…"

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
                .tint(.primary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    LoadingView()
}
