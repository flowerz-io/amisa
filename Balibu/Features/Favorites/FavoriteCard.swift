//
//  FavoriteCard.swift
//

import SwiftUI
import UIKit

typealias FavoriteItem = FavoriteSearchRecord

/// Carte favori strictement fixe, indépendante du layout interne de l'image.
struct FavoriteCard: View {
    let favorite: FavoriteItem
    let cardWidth: CGFloat

    private let cardHeight: CGFloat = 245
    private let imageHeight: CGFloat = 160
    private let cornerRadius: CGFloat = 18

    var body: some View {
        ZStack(alignment: .top) {
            Color(.secondarySystemBackground)

            VStack(spacing: 0) {
                ZStack {
                    Color(.tertiarySystemBackground)
                    favoriteImageLayer
                }
                .frame(width: cardWidth, height: imageHeight)
                .clipped()

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    Text(favorite.dateText)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(favorite.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(height: 42, alignment: .topLeading)
                }
                .padding(12)
                .frame(width: cardWidth, alignment: .leading)
                .frame(height: cardHeight - imageHeight)
                .background(Color(.secondarySystemBackground))
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var favoriteImageLayer: some View {
        if let image = favoriteImage {
            image
                .resizable()
                .scaledToFill()
                .frame(width: cardWidth, height: imageHeight)
                .clipped()
        } else {
            Image(systemName: "photo")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .frame(width: cardWidth, height: imageHeight)
        }
    }

    private var favoriteImage: Image? {
        if let thumbURL = favorite.thumbnailImageURL,
           let data = try? Data(contentsOf: thumbURL),
           let ui = UIImage(data: data) {
            return Image(uiImage: ui)
        }

        if let name = favorite.imageFileName,
           let ui = ImagePersistenceService.shared.loadUIImage(fileName: name) {
            return Image(uiImage: ui)
        }

        return nil
    }
}

private extension FavoriteSearchRecord {
    static let cardDateFormat: Date.FormatStyle =
        .dateTime.day().month(.abbreviated).year().hour().minute()

    var dateText: String {
        createdAt.formatted(Self.cardDateFormat)
    }

    var title: String {
        searchQuery
    }
}
