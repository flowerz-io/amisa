//
//  FavoriteAnalysisCard.swift
//  Balibu
//

import SwiftUI
import UIKit

struct FavoriteAnalysisCard: View {
    let record: FavoriteSearchRecord

    private static let dateTimeFormat: Date.FormatStyle =
        .dateTime.day().month(.abbreviated).year().hour().minute()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            thumbnail
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM, style: .continuous))

            Text(record.createdAt.formatted(Self.dateTimeFormat))
                .font(DesignTokens.captionFont)
                .foregroundStyle(DesignTokens.textSecondary)
                .lineLimit(1)

            Text(record.searchQuery)
                .font(DesignTokens.bodyFont)
                .foregroundStyle(DesignTokens.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.85)
        }
        .padding(DesignTokens.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusM, style: .continuous))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbURL = record.thumbnailImageURL,
           let data = try? Data(contentsOf: thumbURL),
           let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else if let name = record.imageFileName,
                  let ui = ImagePersistenceService.shared.loadUIImage(fileName: name) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusS, style: .continuous)
                .fill(DesignTokens.accentMuted)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
        }
    }
}
