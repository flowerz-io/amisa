//
//  AllPhotoAnalysesView.swift
//  Balibu
//
//  Grille complète de toutes les analyses photo —
//  accessible depuis ProfileView via "Voir toutes les analyses".
//

import SwiftUI
import UIKit

struct AllPhotoAnalysesView: View {
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss

    private let moodColumns = [
        GridItem(.adaptive(minimum: 72), spacing: 6),
    ]

    private var allSessions: [SearchSession] {
        SearchHistoryService.shared.fetchSessions().filter { session in
            guard session.mode == .imageAnalysis else { return false }
            return session.imageFileName != nil || session.thumbnailImageURL != nil
        }
    }

    var body: some View {
        ScrollView {
            if allSessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("Aucune analyse photo pour l'instant.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: moodColumns, spacing: 6) {
                    ForEach(allSessions) { session in
                        Button {
                            dismiss()
                            router.navigateToResults(session: session)
                        } label: {
                            moodThumb(for: session)
                                .aspectRatio(1, contentMode: .fill)
                                .frame(minWidth: 72, minHeight: 72)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .background(DesignTokens.backgroundColor)
        .navigationTitle("Toutes tes analyses")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func moodThumb(for session: SearchSession) -> some View {
        if let ui = session.sourceImage {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else if let thumb = session.thumbnailImageURL,
                  let data = try? Data(contentsOf: thumb),
                  let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignTokens.accentMuted)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(DesignTokens.textSecondary)
                }
        }
    }
}

#Preview {
    NavigationStack {
        AllPhotoAnalysesView()
            .environmentObject(Router())
    }
}
