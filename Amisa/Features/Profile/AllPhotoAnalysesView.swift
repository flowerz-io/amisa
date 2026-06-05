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

    private var allSessions: [SearchSession] {
        SearchHistoryService.shared.fetchSessions().filter { session in
            guard session.mode == .imageAnalysis else { return false }
            return session.imageFileName != nil || session.thumbnailImageURL != nil
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 16
            let columnSpacing: CGFloat = AmisaChrome.analysisGridSpacing
            let cardWidth = floor((proxy.size.width - horizontalPadding * 2 - columnSpacing) / 2)

            ScrollView {
                if allSessions.isEmpty {
                    AmisaPremiumEmptyState(
                        icon: "photo.stack",
                        title: String(localized: "Aucune analyse photo"),
                        message: String(localized: "Tes analyses apparaîtront ici après avoir scanné tes premières pièces."),
                        secondaryActionTitle: String(localized: "Analyser une photo"),
                        secondaryAction: {
                            dismiss()
                            router.openPhotoAnalysis()
                        }
                    )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 32)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.fixed(cardWidth), spacing: columnSpacing),
                            GridItem(.fixed(cardWidth), spacing: columnSpacing),
                        ],
                        spacing: columnSpacing
                    ) {
                        ForEach(allSessions) { session in
                            Button {
                                dismiss()
                                router.navigateToResults(session: session)
                            } label: {
                                analysisCard(for: session, width: cardWidth)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 16)
                }
            }
        }
        .background(DesignTokens.backgroundColor)
        .navigationTitle(String(localized: "Toutes tes analyses"))
        .navigationBarTitleDisplayMode(.large)
    }

    private func analysisCard(for session: SearchSession, width: CGFloat) -> some View {
        moodThumb(for: session)
            .frame(width: width, height: width * 1.12)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: AmisaChrome.analysisThumbRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AmisaChrome.analysisThumbRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
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
            RoundedRectangle(cornerRadius: AmisaChrome.analysisThumbRadius, style: .continuous)
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
